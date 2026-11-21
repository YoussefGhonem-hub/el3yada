using El3yada.Api.Auth;
using El3yada.Api.Infrastructure.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace El3yada.Api.Infrastructure.Realtime;

/// <summary>
/// The app's SignalR connection (<c>/hubs/app</c>): notifications for running apps (Windows toasts),
/// chat messages and unread counts, and live board changes (spec 9.6, 10.2). Clients only listen;
/// every change goes through the REST API.
/// </summary>
[Authorize(Policy = Policies.SignedIn)]
public sealed class AppHub(StaffAccess staff) : Hub
{
    public const string Path = "/hubs/app";

    public static string UserGroup(Guid userId) => $"user:{userId}";
    public static string BoardGroup(Guid branchId) => $"board:{branchId}";
    public static string QueueGroup(Guid branchId) => $"queue:{branchId}";

    public override async Task OnConnectedAsync()
    {
        if (HttpCurrentUser.TryGetUserId(Context.User) is { } userId)
            await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(userId));
        await base.OnConnectedAsync();
    }

    /// <summary>Staff watch one branch's live board. Checked against the caller's branches and permissions.</summary>
    public async Task JoinBoard(Guid branchId)
    {
        var userId = HttpCurrentUser.TryGetUserId(Context.User) ?? throw new HubException("FORBIDDEN");
        var role = Context.User?.FindFirst(ClaimNames.Role)?.Value ?? throw new HubException("FORBIDDEN");
        StaffContext context;
        try
        {
            context = await staff.GetForAsync(userId, role, Context.ConnectionAborted);
            context.Require(StaffPermission.AppointmentsView).RequireBranch(branchId);
        }
        catch (Errors.ApiException error)
        {
            throw new HubException(error.Code);
        }
        await Groups.AddToGroupAsync(Context.ConnectionId, BoardGroup(branchId));
    }

    public Task LeaveBoard(Guid branchId) => Groups.RemoveFromGroupAsync(Context.ConnectionId, BoardGroup(branchId));

    /// <summary>"Now serving" numbers only, no names: any signed-in user (BR-AP15).</summary>
    public Task JoinQueue(Guid branchId) => Groups.AddToGroupAsync(Context.ConnectionId, QueueGroup(branchId));

    public Task LeaveQueue(Guid branchId) => Groups.RemoveFromGroupAsync(Context.ConnectionId, QueueGroup(branchId));
}

/// <summary>Event names the app listens for.</summary>
public static class RealtimeEvents
{
    public const string Notification = "notification";
    public const string ChatMessage = "chatMessage";
    public const string ChatRead = "chatRead";
    public const string BoardChanged = "boardChanged";
    public const string QueueChanged = "queueChanged";
}

/// <summary>Sends events to connected apps. Fire and forget: a missed event is caught up by the next fetch.</summary>
public interface IRealtime
{
    Task ToUserAsync(Guid userId, string eventName, object payload);
    Task ToUsersAsync(IEnumerable<Guid> userIds, string eventName, object payload);
    Task ToBoardAsync(Guid branchId, object payload);
    Task ToQueueAsync(Guid branchId, object payload);
}

public sealed class SignalRRealtime(IHubContext<AppHub> hub, ILogger<SignalRRealtime> logger) : IRealtime
{
    public Task ToUserAsync(Guid userId, string eventName, object payload) =>
        Safe(() => hub.Clients.Group(AppHub.UserGroup(userId)).SendAsync(eventName, payload));

    public Task ToUsersAsync(IEnumerable<Guid> userIds, string eventName, object payload) =>
        Safe(() => hub.Clients.Groups(userIds.Distinct().Select(AppHub.UserGroup).ToList()).SendAsync(eventName, payload));

    public Task ToBoardAsync(Guid branchId, object payload) =>
        Safe(() => hub.Clients.Group(AppHub.BoardGroup(branchId)).SendAsync(RealtimeEvents.BoardChanged, payload));

    public Task ToQueueAsync(Guid branchId, object payload) =>
        Safe(() => hub.Clients.Group(AppHub.QueueGroup(branchId)).SendAsync(RealtimeEvents.QueueChanged, payload));

    private async Task Safe(Func<Task> send)
    {
        try
        {
            await send();
        }
        catch (Exception error)
        {
            logger.LogWarning(error, "SignalR send failed");
        }
    }
}
