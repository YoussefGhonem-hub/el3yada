using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Paging;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Notifications;

public sealed record RegisterDeviceRequest(string DeviceId, string Platform, string? FcmToken, string AppVersion);

public sealed class RegisterDeviceRequestValidator : AbstractValidator<RegisterDeviceRequest>
{
    public RegisterDeviceRequestValidator()
    {
        RuleFor(x => x.DeviceId).NotEmpty().MaximumLength(64).WithErrorCode("INVALID_DEVICE");
        RuleFor(x => x.Platform).Must(p => p is "android" or "ios" or "windows" or "macos").WithErrorCode("INVALID_PLATFORM");
        RuleFor(x => x.FcmToken).MaximumLength(4096).WithErrorCode("TOO_LONG");
        RuleFor(x => x.AppVersion).NotEmpty().MaximumLength(20).WithErrorCode("INVALID_VERSION");
    }
}

public sealed record NotificationPage(PagedResult<NotificationDto> Page, int UnreadCount);

public sealed record RealtimeTokenDto(bool Enabled, string? Token);

/// <summary>
/// D21, P13, AS11, AD17 (the notification centres), device registration for push, and
/// <c>getRealtimeToken</c> (spec 9.6). Every signed-in role.
/// </summary>
[ApiController]
[Route("api/me")]
[Authorize(Policy = Policies.SignedIn)]
[Produces("application/json")]
public sealed class NotificationsController(
    AppDbContext db, ICurrentUser user, IRealtimeTokenIssuer realtimeTokens, StaffAccess staff, TimeProvider clock) : ControllerBase
{
    [HttpGet("notifications", Name = "getNotifications")]
    public async Task<NotificationPage> List([FromQuery] PageQuery paging, CancellationToken ct)
    {
        var mine = db.Notifications.AsNoTracking().Where(n => n.RecipientUserId == user.UserId);
        var page = await mine.OrderByDescending(n => n.CreatedAt).ToPagedAsync(paging, ct);
        var unread = await mine.CountAsync(n => !n.IsRead, ct);
        return new NotificationPage(
            new PagedResult<NotificationDto>(page.Items.Select(NotificationDispatcher.ToDto).ToList(), page.Page, page.PageSize, page.TotalCount),
            unread);
    }

    [HttpGet("notifications/unread-count", Name = "getUnreadNotificationCount")]
    public async Task<object> UnreadCount(CancellationToken ct) =>
        new { count = await db.Notifications.CountAsync(n => n.RecipientUserId == user.UserId && !n.IsRead, ct) };

    [HttpPost("notifications/{id:guid}/read", Name = "markNotificationRead")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        await db.Notifications.Where(n => n.Id == id && n.RecipientUserId == user.UserId && !n.IsRead)
            .ExecuteUpdateAsync(u => u.SetProperty(n => n.IsRead, true).SetProperty(n => n.ReadAt, now), ct);
        return NoContent();
    }

    [HttpPost("notifications/read-all", Name = "markAllNotificationsRead")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        await db.Notifications.Where(n => n.RecipientUserId == user.UserId && !n.IsRead)
            .ExecuteUpdateAsync(u => u.SetProperty(n => n.IsRead, true).SetProperty(n => n.ReadAt, now), ct);
        return NoContent();
    }

    /// <summary>Registers this device (after login, and whenever the FCM token changes).</summary>
    [HttpPut("devices", Name = "registerDevice")]
    public async Task<IActionResult> RegisterDevice(RegisterDeviceRequest request, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var token = string.IsNullOrWhiteSpace(request.FcmToken) ? null : request.FcmToken;

        // A token belongs to one device and one user: a phone that changes account must stop
        // receiving the previous user's pushes.
        if (token is not null)
        {
            await db.UserDevices.Where(d => d.FcmToken == token && !(d.UserId == user.UserId && d.DeviceId == request.DeviceId))
                .ExecuteUpdateAsync(u => u.SetProperty(d => d.FcmToken, (string?)null), ct);
        }

        var device = await db.UserDevices.FirstOrDefaultAsync(d => d.UserId == user.UserId && d.DeviceId == request.DeviceId, ct);
        if (device is null)
        {
            db.UserDevices.Add(new UserDevice
            {
                Id = NewId.Next(), UserId = user.UserId, DeviceId = request.DeviceId, Platform = request.Platform,
                FcmToken = token, AppVersion = request.AppVersion, UpdatedAt = now,
            });
        }
        else
        {
            device.Platform = request.Platform;
            device.FcmToken = token;
            device.AppVersion = request.AppVersion;
            device.UpdatedAt = now;
        }
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>Logout removes this device's push token (spec 7.2).</summary>
    [HttpDelete("devices/{deviceId}", Name = "unregisterDevice")]
    public async Task<IActionResult> UnregisterDevice(string deviceId, CancellationToken ct)
    {
        await db.UserDevices.Where(d => d.UserId == user.UserId && d.DeviceId == deviceId).ExecuteDeleteAsync(ct);
        return NoContent();
    }

    /// <summary>
    /// <c>getRealtimeToken</c>: a Firebase custom token with the caller's claims, for the Firestore
    /// live board. <c>enabled = false</c> while Firebase isn't configured: apps then use SignalR.
    /// </summary>
    [HttpPost("realtime-token", Name = "getRealtimeToken")]
    public async Task<RealtimeTokenDto> RealtimeToken(CancellationToken ct)
    {
        if (!realtimeTokens.Enabled) return new RealtimeTokenDto(false, null);

        var claims = new Dictionary<string, object> { ["role"] = user.Role };
        if (user.Role is Roles.Doctor or Roles.Assistant)
        {
            var context = await staff.GetAsync(ct);
            claims["doctorId"] = context.DoctorId.ToString();
            claims["branchIds"] = context.BranchIds.Select(b => b.ToString()).ToList();
        }
        else if (user.Role == Roles.Patient)
        {
            var patientId = await db.Patients.Where(p => p.UserId == user.UserId).Select(p => p.Id).FirstOrDefaultAsync(ct);
            claims["patientId"] = patientId.ToString();
        }
        return new RealtimeTokenDto(true, await realtimeTokens.CreateAsync(user.UserId, claims, ct));
    }
}
