using El3yada.Api.Auth;
using El3yada.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// Notification preferences (Users.Notify*). <c>chat</c> and <c>reminders</c> default to on; <c>showPreview</c>
/// (message text in pushes, spec 10.1 privacy) and <c>bookings</c> (the doctor's booking alerts, 10.1) to off.
/// </summary>
public sealed record NotificationPrefsView(bool Chat, bool Reminders, bool ShowPreview, bool Bookings);

/// <summary>Only the fields sent change; null or absent keeps the current value.</summary>
public sealed record UpdateNotificationPrefsRequest(bool? Chat, bool? Reminders, bool? ShowPreview, bool? Bookings);

/// <summary>
/// The signed-in user's own notification preferences (D24, AS12, and the patient and admin settings later).
/// Personal, so any role, and an assistant changes their own, never the doctor's. Push delivery reads them in
/// Phase 5. Language and appearance stay in <c>POST /api/auth/updatePreferences</c>.
/// </summary>
[ApiController]
[Route("api/me")]
public sealed class NotificationPrefsController(AppDbContext db, TimeProvider time) : ControllerBase
{
    [HttpGet("notificationPrefs")]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await db.Users.AsNoTracking()
            .Where(u => u.Id == User.UserId())
            .Select(u => new NotificationPrefsView(u.NotifyChat, u.NotifyReminders, u.NotifyShowPreview, u.NotifyBookings))
            .SingleAsync(cancellationToken));

    [HttpPost("updateNotificationPrefs")]
    public async Task<IActionResult> Update(UpdateNotificationPrefsRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        user.NotifyChat = request.Chat ?? user.NotifyChat;
        user.NotifyReminders = request.Reminders ?? user.NotifyReminders;
        user.NotifyShowPreview = request.ShowPreview ?? user.NotifyShowPreview;
        user.NotifyBookings = request.Bookings ?? user.NotifyBookings;
        user.UpdatedAt = time.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(cancellationToken);
        return Ok(new NotificationPrefsView(user.NotifyChat, user.NotifyReminders, user.NotifyShowPreview, user.NotifyBookings));
    }
}
