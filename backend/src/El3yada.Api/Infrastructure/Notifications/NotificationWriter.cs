using System.Text.Json;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Infrastructure.Notifications;

/// <summary>One notification in both languages (spec 10.1). Never put diagnoses or file contents here.</summary>
public sealed record NotificationMessage(
    string Type,
    string TitleAr,
    string TitleEn,
    string BodyAr,
    string BodyEn,
    string? Route = null,
    object? Data = null);

/// <summary>
/// Stores in-app notifications. Rows are added to the context and saved with the change that caused them.
/// Phase 5 adds delivery (FCM, SignalR) behind this same interface, so callers don't change.
/// </summary>
public interface INotificationWriter
{
    void Add(Guid recipientUserId, NotificationMessage message);

    /// <summary>Every active admin (AD17: sign-ups, payments, deletion requests).</summary>
    Task AddForAdminsAsync(NotificationMessage message, CancellationToken ct);
}

public sealed class NotificationWriter(AppDbContext db, TimeProvider clock) : INotificationWriter
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public void Add(Guid recipientUserId, NotificationMessage message)
    {
        db.Notifications.Add(new Notification
        {
            Id = NewId.Next(),
            RecipientUserId = recipientUserId,
            Type = message.Type,
            TitleAr = message.TitleAr,
            TitleEn = message.TitleEn,
            BodyAr = message.BodyAr,
            BodyEn = message.BodyEn,
            Route = message.Route,
            DataJson = message.Data is null ? null : JsonSerializer.Serialize(message.Data, Json),
            CreatedAt = clock.GetUtcNow().UtcDateTime,
        });
    }

    public async Task AddForAdminsAsync(NotificationMessage message, CancellationToken ct)
    {
        var admins = await db.Users
            .Where(u => u.Role == Roles.Admin && u.Status == "active")
            .Select(u => u.Id)
            .ToListAsync(ct);
        foreach (var id in admins) Add(id, message);
    }
}
