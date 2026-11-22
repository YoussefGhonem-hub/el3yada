using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Files;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Realtime;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using ChatEntity = El3yada.Data.Entities.Chat;

namespace El3yada.Api.Features.Chat;

/// <summary>Who is acting on a chat: a patient, or clinic staff.</summary>
public sealed record ChatActor(Guid UserId, string Role, string Name, Guid? PatientId, StaffContext? Staff)
{
    public bool IsPatient => Role == Roles.Patient;
}

/// <summary>
/// Chat (spec 6.8, D16/D17, AS9, P11/P12). One conversation per doctor–patient link (BR-C1).
/// Patients talk to their linked doctors; the doctor and assistants with <c>chat</c> answer for the clinic
/// (BR-C8). Messages are never edited or deleted (BR-C7); admins have no access.
/// </summary>
public sealed class ChatService(
    AppDbContext db,
    ICurrentUser user,
    StaffAccess staffAccess,
    PatientContext patientContext,
    IFileStorage storage,
    INotificationWriter notifications,
    NotificationRecipients recipients,
    IRealtime realtime,
    IAuditLogger audit,
    TimeProvider clock)
{
    // ---- Who is calling ----------------------------------------------------------------------

    public async Task<ChatActor> StaffActorAsync(CancellationToken ct)
    {
        var staff = (await staffAccess.GetAsync(ct)).Require(StaffPermission.Chat);
        return new ChatActor(staff.UserId, staff.Role, staff.DisplayName, null, staff);
    }

    public async Task<ChatActor> PatientActorAsync(CancellationToken ct)
    {
        var pid = await patientContext.GetPatientIdAsync(ct);
        var name = await db.Patients.Where(p => p.Id == pid).Select(p => p.FullName).FirstAsync(ct);
        return new ChatActor(user.UserId, Roles.Patient, name, pid, null);
    }

    private IQueryable<ChatEntity> ChatsOf(ChatActor actor) => actor.IsPatient
        ? db.Chats.Where(c => c.PatientId == actor.PatientId)
        : db.Chats.Where(c => c.DoctorId == actor.Staff!.DoctorId);

    // ---- Inbox (D16, P11) --------------------------------------------------------------------

    public async Task<IReadOnlyList<ChatSummaryDto>> InboxAsync(ChatActor actor, string? search, CancellationToken ct)
    {
        if (actor.IsPatient) await EnsureChatsForPatientAsync(actor.PatientId!.Value, ct);

        var query = ChatsOf(actor).AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = actor.IsPatient
                ? query.Where(c => c.Doctor.FullName.Contains(term) || (c.Doctor.FullNameEn != null && c.Doctor.FullNameEn.Contains(term)))
                : query.Where(c => c.Link.PatientName.Contains(term) || c.Link.PatientPhone.Contains(term));
        }

        var rows = await Project(query.OrderByDescending(c => c.LastMessageAt ?? c.CreatedAt).Take(200), actor.UserId)
            .ToListAsync(ct);
        return rows.Select(r => ToSummary(r, actor)).ToList();
    }

    public async Task<int> UnreadTotalAsync(ChatActor actor, CancellationToken ct) =>
        await db.ChatReadStates.AsNoTracking()
            .Where(s => s.UserId == actor.UserId && ChatsOf(actor).Any(c => c.Id == s.ChatId))
            .SumAsync(s => s.UnreadCount, ct);

    /// <summary>Staff open the chat from a patient profile: the link's chat, created if it is missing.</summary>
    public async Task<ChatSummaryDto> OpenForPatientAsync(ChatActor actor, Guid patientId, CancellationToken ct)
    {
        var link = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == actor.Staff!.DoctorId && l.PatientId == patientId)
            .Select(l => new { l.Id, l.DoctorId, l.PatientId })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound(ErrorCodes.NotLinked);
        var chatId = await EnsureChatAsync(link.Id, link.DoctorId, link.PatientId, ct);
        return await SummaryAsync(actor, chatId, ct);
    }

    // ---- Thread (D17, P12) -------------------------------------------------------------------

    public async Task<ChatThreadDto> ThreadAsync(ChatActor actor, Guid chatId, ChatThreadQuery query, CancellationToken ct)
    {
        var summary = await SummaryAsync(actor, chatId, ct);
        var limit = Math.Clamp(query.Limit, 1, 100);

        var messages = db.ChatMessages.AsNoTracking().Where(m => m.ChatId == chatId);
        if (query.Before is { } before)
        {
            var cursor = await db.ChatMessages.AsNoTracking().Where(m => m.Id == before && m.ChatId == chatId)
                .Select(m => (DateTime?)m.CreatedAt).FirstOrDefaultAsync(ct);
            if (cursor is { } at) messages = messages.Where(m => m.CreatedAt < at || (m.CreatedAt == at && m.Id.CompareTo(before) < 0));
        }

        var page = await messages
            .OrderByDescending(m => m.CreatedAt).ThenByDescending(m => m.Id)
            .Take(limit + 1)
            .Select(m => new ChatMessageDto(
                m.Id, m.ChatId, m.SenderId, m.SenderRole, m.SenderName, m.Type, m.Text,
                m.AttachmentPath == null ? null : new ChatAttachmentDto(m.AttachmentFileName!, m.AttachmentMimeType!, m.AttachmentSizeBytes ?? 0),
                m.CreatedAt, m.ReadAt,
                db.MedicalRecords.Where(r => r.SourceChatMessageId == m.Id && !r.Deleted).Select(r => (Guid?)r.Id).FirstOrDefault()))
            .ToListAsync(ct);

        var hasMore = page.Count > limit;
        if (hasMore) page.RemoveAt(page.Count - 1);
        // Patients don't learn which clinic records exist beyond what they see in their file.
        if (actor.IsPatient) page = page.Select(m => m with { SavedRecordId = null }).ToList();
        return new ChatThreadDto(summary, page, hasMore);
    }

    // ---- Sending -----------------------------------------------------------------------------

    public Task<ChatMessageDto> SendTextAsync(ChatActor actor, Guid chatId, string text, CancellationToken ct) =>
        SendAsync(actor, chatId, "text", text.Trim(), null, ct);

    public async Task<ChatMessageDto> SendFileAsync(ChatActor actor, Guid chatId, IFormFile file, CancellationToken ct)
    {
        if (file is null || file.Length == 0) throw ApiException.BadRequest(ErrorCodes.FileRequired);
        var maxMb = await db.AppSettings.AsNoTracking().Select(s => s.MaxUploadMb).FirstAsync(ct);
        if (file.Length > maxMb * 1024L * 1024L) throw new ApiException(StatusCodes.Status400BadRequest, ErrorCodes.FileTooLarge) { Details = new { maxMb } };

        // Chat takes the same files as the medical record: JPEG, PNG, WebP and PDF (the stored path comes from IDs).
        var mime = El3yada.Api.Storage.FileTypes.Normalize(file.ContentType)
            ?? throw ApiException.BadRequest(ErrorCodes.FileTypeNotAllowed);
        var type = El3yada.Api.Storage.FileTypes.IsImage(mime) ? "image" : "file";
        return await SendAsync(actor, chatId, type, null, file, ct);
    }

    private async Task<ChatMessageDto> SendAsync(ChatActor actor, Guid chatId, string type, string? text, IFormFile? file, CancellationToken ct)
    {
        var chat = await ChatsOf(actor).Include(c => c.Doctor).FirstOrDefaultAsync(c => c.Id == chatId, ct)
            ?? throw ApiException.NotFound();

        // Spec 6.17: a chat whose patient or doctor account is being deleted (or was erased) is closed for both sides.
        var accounts = await db.Chats.AsNoTracking().Where(c => c.Id == chat.Id)
            .Select(c => new { Patient = c.Patient.User.Status, Doctor = c.Doctor.User.Status })
            .FirstAsync(ct);
        if (accounts.Patient != "active" || accounts.Doctor != "active")
            throw ApiException.Forbidden(ErrorCodes.ChatClosed);

        // BR-G5 / P12: a suspended doctor's clinic can't send, and patients see "the doctor isn't available".
        if (chat.Doctor.Status == "suspended")
            throw ApiException.Forbidden(actor.IsPatient ? ErrorCodes.ChatUnavailable : ErrorCodes.DoctorSuspended);
        if (chat.Doctor.Status != "active" || (actor.IsPatient && !chat.Enabled))
            throw ApiException.Forbidden(ErrorCodes.ChatUnavailable);

        var now = clock.GetUtcNow().UtcDateTime;
        var message = new ChatMessage
        {
            Id = NewId.Next(),
            ChatId = chat.Id,
            SenderId = actor.UserId,
            SenderRole = actor.Role,
            SenderName = actor.Name,
            Type = type,
            Text = text,
            CreatedAt = now,
        };

        if (file is not null)
        {
            var fileName = SafeFileName(file.FileName);
            message.AttachmentPath = El3yada.Api.Storage.StoragePath.ChatAttachment(chat.Id, message.Id, El3yada.Api.Storage.FileTypes.Normalize(file.ContentType)!).Value;
            message.AttachmentFileName = fileName;
            message.AttachmentMimeType = El3yada.Api.Storage.FileTypes.Normalize(file.ContentType)!;
            message.AttachmentSizeBytes = file.Length;
            await using var stream = file.OpenReadStream();
            try
            {
                await storage.SaveAsync(message.AttachmentPath, stream, ct);
            }
            catch (El3yada.Api.Storage.FileStorageException ex)
            {
                throw ApiException.BadRequest(ex.Code);
            }
        }

        db.ChatMessages.Add(message);
        chat.LastMessageText = text is null ? null : (text.Length > 200 ? text[..200] : text);
        chat.LastMessageType = type;
        chat.LastMessageSenderId = actor.UserId;
        chat.LastMessageAt = now;

        // Unread counts: the other side only. Staff messages count for the patient; patient
        // messages count for the doctor and every assistant with `chat` (each has their own count).
        var patientUserId = await db.Patients.Where(p => p.Id == chat.PatientId).Select(p => p.UserId).FirstAsync(ct);
        var staffIds = await recipients.StaffAsync(chat.DoctorId, StaffPermission.Chat, ct: ct);
        var toNotify = actor.IsPatient ? staffIds : [patientUserId];

        await IncrementUnreadAsync(chat.Id, toNotify, ct);

        var route = actor.IsPatient ? $"/doctor/chats/{chat.Id}" : $"/patient/chats/{chat.Id}";
        var senderLabel = actor.IsPatient ? actor.Name : chat.Doctor.FullName;
        foreach (var recipient in toNotify)
        {
            var staffRoute = actor.IsPatient && recipient != chat.DoctorId ? $"/assistant/chats/{chat.Id}" : route;
            notifications.Add(recipient, NotificationTemplates.ChatMessage(senderLabel, chat.Id, message.Id, staffRoute));
        }

        if (!actor.IsPatient)
            audit.Add("chat.messageSent", "ChatMessage", message.Id, chat.DoctorId, chat.PatientId, new { type });

        await db.SaveChangesAsync(ct);

        var dto = ToDto(message);
        await realtime.ToUsersAsync([.. staffIds, patientUserId], RealtimeEvents.ChatMessage, dto);
        return dto;
    }

    /// <summary>Marks the conversation read for the caller and sets the other side's read ticks (BR-C3).</summary>
    public async Task MarkReadAsync(ChatActor actor, Guid chatId, CancellationToken ct)
    {
        var chat = await ChatsOf(actor).AsNoTracking().Select(c => new { c.Id, c.DoctorId, c.PatientId })
            .FirstOrDefaultAsync(c => c.Id == chatId, ct) ?? throw ApiException.NotFound();
        var now = clock.GetUtcNow().UtcDateTime;

        await db.ChatReadStates.Where(s => s.ChatId == chatId && s.UserId == actor.UserId)
            .ExecuteUpdateAsync(u => u.SetProperty(s => s.UnreadCount, 0).SetProperty(s => s.LastReadAt, now), ct);

        var updated = actor.IsPatient
            ? await db.ChatMessages.Where(m => m.ChatId == chatId && m.SenderRole != Roles.Patient && m.ReadAt == null)
                .ExecuteUpdateAsync(u => u.SetProperty(m => m.ReadAt, now), ct)
            : await db.ChatMessages.Where(m => m.ChatId == chatId && m.SenderRole == Roles.Patient && m.ReadAt == null)
                .ExecuteUpdateAsync(u => u.SetProperty(m => m.ReadAt, now), ct);

        if (updated > 0)
        {
            var patientUserId = await db.Patients.Where(p => p.Id == chat.PatientId).Select(p => p.UserId).FirstAsync(ct);
            var staffIds = await recipients.StaffAsync(chat.DoctorId, StaffPermission.Chat, ct: ct);
            await realtime.ToUsersAsync([.. staffIds, patientUserId], RealtimeEvents.ChatRead,
                new { chatId, readerRole = actor.IsPatient ? Roles.Patient : "clinic", at = now });
        }
    }

    /// <summary>BR-C6 [C]: the doctor switches chat off or on for one patient. Doctor only.</summary>
    public async Task<ChatSummaryDto> SetEnabledAsync(ChatActor actor, Guid chatId, bool enabled, CancellationToken ct)
    {
        if (actor.Staff is not { IsDoctor: true }) throw ApiException.Forbidden(ErrorCodes.PermissionDenied);
        var chat = await ChatsOf(actor).FirstOrDefaultAsync(c => c.Id == chatId, ct) ?? throw ApiException.NotFound();
        if (chat.Enabled != enabled)
        {
            chat.Enabled = enabled;
            audit.Add(enabled ? "chat.enabled" : "chat.disabled", "Chat", chat.Id, chat.DoctorId, chat.PatientId);
            await db.SaveChangesAsync(ct);
        }
        return await SummaryAsync(actor, chatId, ct);
    }

    // ---- Attachments -------------------------------------------------------------------------

    public async Task<(string Path, string FileName, string MimeType)> AttachmentAsync(ChatActor actor, Guid chatId, Guid messageId, CancellationToken ct)
    {
        var m = await db.ChatMessages.AsNoTracking()
            .Where(x => x.Id == messageId && x.ChatId == chatId && ChatsOf(actor).Any(c => c.Id == chatId))
            .Select(x => new { x.AttachmentPath, x.AttachmentFileName, x.AttachmentMimeType })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();
        if (m.AttachmentPath is null) throw ApiException.NotFound(ErrorCodes.FileMissing);
        return (m.AttachmentPath, m.AttachmentFileName!, m.AttachmentMimeType!);
    }

    /// <summary>
    /// BR-C4 "Save to patient file": copies the attachment into a new medical record with
    /// <c>source = chat</c>. Needs <c>filesManage</c>; blocked while the doctor is suspended.
    /// </summary>
    public async Task<Guid> SaveToFileAsync(ChatActor actor, Guid chatId, Guid messageId, SaveToFileRequest request, CancellationToken ct)
    {
        var staff = actor.Staff ?? throw ApiException.Forbidden();
        staff.Require(StaffPermission.FilesManage).RequireNotSuspended();

        var m = await db.ChatMessages.AsNoTracking()
            .Where(x => x.Id == messageId && x.ChatId == chatId && x.Chat.DoctorId == staff.DoctorId)
            .Select(x => new { x.AttachmentPath, x.AttachmentFileName, x.AttachmentMimeType, x.AttachmentSizeBytes, x.Chat.PatientId, x.CreatedAt })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();
        if (m.AttachmentPath is null) throw ApiException.BadRequest(ErrorCodes.FileRequired);

        var already = await db.MedicalRecords.AsNoTracking()
            .Where(r => r.SourceChatMessageId == messageId && !r.Deleted).Select(r => (Guid?)r.Id).FirstOrDefaultAsync(ct);
        if (already is { } existing) return existing;

        var now = clock.GetUtcNow().UtcDateTime;
        var record = new MedicalRecord
        {
            Id = NewId.Next(),
            DoctorId = staff.DoctorId,
            PatientId = m.PatientId,
            Category = request.Category,
            OtherType = request.OtherType,
            OtherTypeText = request.OtherTypeText,
            Title = string.IsNullOrWhiteSpace(request.Title) ? m.AttachmentFileName! : request.Title.Trim(),
            DocumentDate = request.DocumentDate ?? CairoTime.Today(clock),
            Notes = request.Notes,
            Source = "chat",
            SourceChatMessageId = messageId,
            CreatedBy = staff.UserId,
            CreatedByRole = staff.Role,
            CreatedAt = now,
            UpdatedAt = now,
        };
        var attachmentId = NewId.Next();
        var path = El3yada.Api.Storage.StoragePath.MedicalAttachment(staff.DoctorId, m.PatientId, record.Id, attachmentId, m.AttachmentMimeType!).Value;
        await using (var source = await storage.OpenReadAsync(m.AttachmentPath, ct) ?? throw ApiException.NotFound(ErrorCodes.FileMissing))
        {
            await storage.SaveAsync(path, source, ct);
        }
        record.MedicalRecordAttachments.Add(new MedicalRecordAttachment
        {
            Id = attachmentId, Path = path, FileName = m.AttachmentFileName!, MimeType = m.AttachmentMimeType!,
            SizeBytes = m.AttachmentSizeBytes ?? 1, StoredSizeBytes = m.AttachmentSizeBytes ?? 1,
        });
        db.MedicalRecords.Add(record);

        var patientUserId = await db.Patients.Where(p => p.Id == m.PatientId).Select(p => p.UserId).FirstAsync(ct);
        notifications.Add(patientUserId, NotificationTemplates.FileAdded(record.Id));   // BR-F9
        audit.Add("record.savedFromChat", nameof(MedicalRecord), record.Id, staff.DoctorId, m.PatientId, new { messageId });

        await db.SaveChangesAsync(ct);
        return record.Id;
    }

    // ---- Helpers -----------------------------------------------------------------------------

    private sealed record ChatRow(
        Guid Id, Guid DoctorId, Guid PatientId, bool Enabled, DateTime CreatedAt, DateTime? LastMessageAt,
        string? LastMessageType, string? LastMessageText, Guid? LastMessageSenderId, string? LastSenderRole,
        string DoctorName, string? DoctorNameEn, string DoctorTitle, string? DoctorTitleEn, string DoctorStatus,
        string PatientName, int FileNumber, int Unread, string PatientUserStatus, string DoctorUserStatus);

    private IQueryable<ChatRow> Project(IQueryable<ChatEntity> chats, Guid userId) => chats.Select(c => new ChatRow(
        c.Id, c.DoctorId, c.PatientId, c.Enabled, c.CreatedAt, c.LastMessageAt, c.LastMessageType, c.LastMessageText,
        c.LastMessageSenderId,
        c.ChatMessages.OrderByDescending(m => m.CreatedAt).Select(m => m.SenderRole).FirstOrDefault(),
        c.Doctor.FullName, c.Doctor.FullNameEn, c.Doctor.Title, c.Doctor.TitleEn, c.Doctor.Status,
        c.Link.PatientName, c.Link.FileNumber,
        db.ChatReadStates.Where(s => s.ChatId == c.Id && s.UserId == userId).Select(s => s.UnreadCount).FirstOrDefault(),
        c.Patient.User.Status, c.Doctor.User.Status));

    private async Task<ChatSummaryDto> SummaryAsync(ChatActor actor, Guid chatId, CancellationToken ct)
    {
        var row = await Project(ChatsOf(actor).AsNoTracking().Where(c => c.Id == chatId), actor.UserId).FirstOrDefaultAsync(ct)
            ?? throw ApiException.NotFound();
        return ToSummary(row, actor);
    }

    private static ChatSummaryDto ToSummary(ChatRow r, ChatActor actor)
    {
        // Spec 6.17: closed while either account is being deleted, and for good once it is erased.
        string? unavailable = r.PatientUserStatus != "active" || r.DoctorUserStatus != "active"
            ? ErrorCodes.ChatClosed
            : r.DoctorStatus switch
            {
                "suspended" => actor.IsPatient ? ErrorCodes.ChatUnavailable : ErrorCodes.DoctorSuspended,
                "active" => actor.IsPatient && !r.Enabled ? ErrorCodes.ChatUnavailable : null,
                _ => ErrorCodes.ChatUnavailable,
            };
        var counterpart = actor.IsPatient
            ? new ChatCounterpartDto(r.DoctorId, r.DoctorName, r.DoctorNameEn, r.DoctorTitle, r.DoctorTitleEn)
            : new ChatCounterpartDto(r.PatientId, r.PatientName, null, null, null);
        var last = r.LastMessageAt is { } at
            ? new LastMessageDto(r.LastMessageType ?? "text", r.LastMessageText, r.LastSenderRole ?? "patient", at)
            : null;
        return new ChatSummaryDto(r.Id, r.DoctorId, r.PatientId, counterpart, actor.IsPatient ? null : r.FileNumber,
            last, r.Unread, r.Enabled, unavailable is null, unavailable);
    }

    private static ChatMessageDto ToDto(ChatMessage m) => new(
        m.Id, m.ChatId, m.SenderId, m.SenderRole, m.SenderName, m.Type, m.Text,
        m.AttachmentPath is null ? null : new ChatAttachmentDto(m.AttachmentFileName!, m.AttachmentMimeType!, m.AttachmentSizeBytes ?? 0),
        m.CreatedAt, m.ReadAt, null);

    private async Task IncrementUnreadAsync(Guid chatId, IReadOnlyList<Guid> userIds, CancellationToken ct)
    {
        var existing = await db.ChatReadStates.Where(s => s.ChatId == chatId && userIds.Contains(s.UserId)).ToListAsync(ct);
        foreach (var userId in userIds.Distinct())
        {
            var state = existing.FirstOrDefault(s => s.UserId == userId);
            if (state is null) db.ChatReadStates.Add(new ChatReadState { ChatId = chatId, UserId = userId, UnreadCount = 1 });
            else state.UnreadCount++;
        }
    }

    private async Task EnsureChatsForPatientAsync(Guid patientId, CancellationToken ct)
    {
        var missing = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.PatientId == patientId && l.Chat == null)
            .Select(l => new { l.Id, l.DoctorId, l.PatientId })
            .ToListAsync(ct);
        foreach (var link in missing) await EnsureChatAsync(link.Id, link.DoctorId, link.PatientId, ct);
    }

    /// <summary>BR-C1: the link's chat. Normally created with the link (Phase 2 createPatient); created here if missing.</summary>
    public async Task<Guid> EnsureChatAsync(Guid linkId, Guid doctorId, Guid patientId, CancellationToken ct)
    {
        var id = await db.Chats.Where(c => c.LinkId == linkId).Select(c => (Guid?)c.Id).FirstOrDefaultAsync(ct);
        if (id is { } found) return found;

        var chat = new ChatEntity
        {
            Id = NewId.Next(), LinkId = linkId, DoctorId = doctorId, PatientId = patientId, Enabled = true,
            CreatedAt = clock.GetUtcNow().UtcDateTime,
        };
        db.Chats.Add(chat);
        try
        {
            await db.SaveChangesAsync(ct);
            return chat.Id;
        }
        catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
        {
            // Two requests created it at once: use the other one.
            db.Entry(chat).State = EntityState.Detached;
            return await db.Chats.Where(c => c.LinkId == linkId).Select(c => c.Id).FirstAsync(ct);
        }
    }

    private static string SafeFileName(string? name)
    {
        var file = Path.GetFileName(name ?? "");
        foreach (var c in Path.GetInvalidFileNameChars()) file = file.Replace(c, '_');
        file = file.Trim().TrimStart('.');
        if (file.Length == 0) file = "file";
        return file.Length > 120 ? file[^120..] : file;
    }
}
