using El3yada.Api.Auth;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Files;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Features.Chat;

/// <summary>D16/D17 and AS9: the clinic side. Assistants need <c>chat</c>.</summary>
[ApiController]
[Route("api/staff/chats")]
[Authorize(Policy = Policies.Staff)]
[Produces("application/json")]
public sealed class StaffChatController(ChatService chats, IFileStorage storage) : ControllerBase
{
    [HttpGet(Name = "getStaffChats")]
    public async Task<IReadOnlyList<ChatSummaryDto>> Inbox([FromQuery] string? search, CancellationToken ct) =>
        await chats.InboxAsync(await chats.StaffActorAsync(ct), search, ct);

    [HttpGet("unread-count", Name = "getStaffChatUnread")]
    public async Task<object> Unread(CancellationToken ct) => new { count = await chats.UnreadTotalAsync(await chats.StaffActorAsync(ct), ct) };

    /// <summary>Opens (and if needed creates) the chat with a linked patient.</summary>
    [HttpPost("by-patient/{patientId:guid}", Name = "openChatWithPatient")]
    public async Task<ChatSummaryDto> OpenForPatient(Guid patientId, CancellationToken ct) =>
        await chats.OpenForPatientAsync(await chats.StaffActorAsync(ct), patientId, ct);

    [HttpGet("{chatId:guid}", Name = "getStaffChatThread")]
    public async Task<ChatThreadDto> Thread(Guid chatId, [FromQuery] ChatThreadQuery query, CancellationToken ct) =>
        await chats.ThreadAsync(await chats.StaffActorAsync(ct), chatId, query, ct);

    [HttpPost("{chatId:guid}/messages", Name = "sendStaffChatText")]
    public async Task<ChatMessageDto> SendText(Guid chatId, SendTextRequest request, CancellationToken ct) =>
        await chats.SendTextAsync(await chats.StaffActorAsync(ct), chatId, request.Text, ct);

    [HttpPost("{chatId:guid}/attachments", Name = "sendStaffChatFile")]
    [RequestSizeLimit(210L * 1024 * 1024)]
    public async Task<ChatMessageDto> SendFile(Guid chatId, IFormFile file, CancellationToken ct) =>
        await chats.SendFileAsync(await chats.StaffActorAsync(ct), chatId, file, ct);

    [HttpPost("{chatId:guid}/read", Name = "markStaffChatRead")]
    public async Task<IActionResult> Read(Guid chatId, CancellationToken ct)
    {
        await chats.MarkReadAsync(await chats.StaffActorAsync(ct), chatId, ct);
        return NoContent();
    }

    /// <summary>BR-C6: switch chat off or on for this patient (doctor only).</summary>
    [HttpPatch("{chatId:guid}", Name = "setChatEnabled")]
    public async Task<ChatSummaryDto> SetEnabled(Guid chatId, SetChatEnabledRequest request, CancellationToken ct) =>
        await chats.SetEnabledAsync(await chats.StaffActorAsync(ct), chatId, request.Enabled, ct);

    [HttpGet("{chatId:guid}/messages/{messageId:guid}/attachment", Name = "getStaffChatAttachment")]
    public async Task<IActionResult> Attachment(Guid chatId, Guid messageId, CancellationToken ct)
    {
        var (path, name, mime) = await chats.AttachmentAsync(await chats.StaffActorAsync(ct), chatId, messageId, ct);
        return await FileResults.StreamAsync(this, storage, path, mime, name, ct);
    }

    /// <summary>BR-C4: save the attachment into the patient's file. Returns the new record id.</summary>
    [HttpPost("{chatId:guid}/messages/{messageId:guid}/save-to-file", Name = "saveChatAttachmentToFile")]
    public async Task<object> SaveToFile(Guid chatId, Guid messageId, SaveToFileRequest request, CancellationToken ct) =>
        new { recordId = await chats.SaveToFileAsync(await chats.StaffActorAsync(ct), chatId, messageId, request, ct) };
}

/// <summary>P11/P12: the patient side.</summary>
[ApiController]
[Route("api/patient/chats")]
[Authorize(Policy = Policies.Patient)]
[Produces("application/json")]
public sealed class PatientChatController(ChatService chats, IFileStorage storage) : ControllerBase
{
    [HttpGet(Name = "getPatientChats")]
    public async Task<IReadOnlyList<ChatSummaryDto>> Inbox(CancellationToken ct) =>
        await chats.InboxAsync(await chats.PatientActorAsync(ct), null, ct);

    [HttpGet("unread-count", Name = "getPatientChatUnread")]
    public async Task<object> Unread(CancellationToken ct) => new { count = await chats.UnreadTotalAsync(await chats.PatientActorAsync(ct), ct) };

    [HttpGet("{chatId:guid}", Name = "getPatientChatThread")]
    public async Task<ChatThreadDto> Thread(Guid chatId, [FromQuery] ChatThreadQuery query, CancellationToken ct) =>
        await chats.ThreadAsync(await chats.PatientActorAsync(ct), chatId, query, ct);

    [HttpPost("{chatId:guid}/messages", Name = "sendPatientChatText")]
    public async Task<ChatMessageDto> SendText(Guid chatId, SendTextRequest request, CancellationToken ct) =>
        await chats.SendTextAsync(await chats.PatientActorAsync(ct), chatId, request.Text, ct);

    [HttpPost("{chatId:guid}/attachments", Name = "sendPatientChatFile")]
    [RequestSizeLimit(210L * 1024 * 1024)]
    public async Task<ChatMessageDto> SendFile(Guid chatId, IFormFile file, CancellationToken ct) =>
        await chats.SendFileAsync(await chats.PatientActorAsync(ct), chatId, file, ct);

    [HttpPost("{chatId:guid}/read", Name = "markPatientChatRead")]
    public async Task<IActionResult> Read(Guid chatId, CancellationToken ct)
    {
        await chats.MarkReadAsync(await chats.PatientActorAsync(ct), chatId, ct);
        return NoContent();
    }

    [HttpGet("{chatId:guid}/messages/{messageId:guid}/attachment", Name = "getPatientChatAttachment")]
    public async Task<IActionResult> Attachment(Guid chatId, Guid messageId, CancellationToken ct)
    {
        var (path, name, mime) = await chats.AttachmentAsync(await chats.PatientActorAsync(ct), chatId, messageId, ct);
        return await FileResults.StreamAsync(this, storage, path, mime, name, ct);
    }
}
