using System.Data.Common;
using System.Text.Json;
using System.Threading.Channels;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Realtime;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace El3yada.Api.Infrastructure.Notifications;

/// <summary>Ids of saved notifications waiting to be delivered.</summary>
public sealed class NotificationQueue
{
    private readonly Channel<Guid> _channel = Channel.CreateUnbounded<Guid>(new UnboundedChannelOptions { SingleReader = true });

    public ChannelReader<Guid> Reader => _channel.Reader;

    public void Enqueue(IEnumerable<Guid> ids)
    {
        foreach (var id in ids) _channel.Writer.TryWrite(id);
    }
}

/// <summary>
/// Collects <see cref="Notification"/> rows as they are saved and hands them to the dispatcher only
/// once they are committed: straight after <c>SaveChanges</c>, or after the surrounding transaction
/// commits. A rolled-back transaction delivers nothing. This keeps <see cref="INotificationWriter"/>
/// the single place that sends (spec 9.2) without callers having to remember a second step.
/// </summary>
public sealed class NotificationDispatchInterceptor(NotificationQueue queue) : SaveChangesInterceptor, IDbTransactionInterceptor
{
    private readonly List<Guid> _pending = [];
    private readonly List<Guid> _awaitingCommit = [];

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData eventData, InterceptionResult<int> result, CancellationToken ct = default)
    {
        Collect(eventData.Context);
        return base.SavingChangesAsync(eventData, result, ct);
    }

    public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
    {
        Collect(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    public override ValueTask<int> SavedChangesAsync(SaveChangesCompletedEventData eventData, int result, CancellationToken ct = default)
    {
        Release(eventData.Context);
        return base.SavedChangesAsync(eventData, result, ct);
    }

    public override int SavedChanges(SaveChangesCompletedEventData eventData, int result)
    {
        Release(eventData.Context);
        return base.SavedChanges(eventData, result);
    }

    public override void SaveChangesFailed(DbContextErrorEventData eventData) => _pending.Clear();

    public override Task SaveChangesFailedAsync(DbContextErrorEventData eventData, CancellationToken ct = default)
    {
        _pending.Clear();
        return Task.CompletedTask;
    }

    private void Collect(DbContext? context)
    {
        if (context is null) return;
        _pending.AddRange(context.ChangeTracker.Entries<Notification>()
            .Where(e => e.State == EntityState.Added)
            .Select(e => e.Entity.Id));
    }

    private void Release(DbContext? context)
    {
        if (_pending.Count == 0) return;
        if (context?.Database.CurrentTransaction is null) queue.Enqueue(_pending);
        else _awaitingCommit.AddRange(_pending);
        _pending.Clear();
    }

    // IDbTransactionInterceptor: deliver on commit, drop on rollback.
    public void TransactionCommitted(DbTransaction transaction, TransactionEndEventData eventData) => Flush();

    public Task TransactionCommittedAsync(DbTransaction transaction, TransactionEndEventData eventData, CancellationToken ct = default)
    {
        Flush();
        return Task.CompletedTask;
    }

    public void TransactionRolledBack(DbTransaction transaction, TransactionEndEventData eventData) => _awaitingCommit.Clear();

    public Task TransactionRolledBackAsync(DbTransaction transaction, TransactionEndEventData eventData, CancellationToken ct = default)
    {
        _awaitingCommit.Clear();
        return Task.CompletedTask;
    }

    private void Flush()
    {
        queue.Enqueue(_awaitingCommit);
        _awaitingCommit.Clear();
    }

    // The remaining IDbTransactionInterceptor members keep their defaults.
    public InterceptionResult<DbTransaction> TransactionStarting(DbConnection connection, TransactionStartingEventData eventData, InterceptionResult<DbTransaction> result) => result;
    public DbTransaction TransactionStarted(DbConnection connection, TransactionEndEventData eventData, DbTransaction result) => result;
    public ValueTask<InterceptionResult<DbTransaction>> TransactionStartingAsync(DbConnection connection, TransactionStartingEventData eventData, InterceptionResult<DbTransaction> result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public ValueTask<DbTransaction> TransactionStartedAsync(DbConnection connection, TransactionEndEventData eventData, DbTransaction result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public DbTransaction TransactionUsed(DbConnection connection, TransactionEventData eventData, DbTransaction result) => result;
    public ValueTask<DbTransaction> TransactionUsedAsync(DbConnection connection, TransactionEventData eventData, DbTransaction result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public InterceptionResult TransactionCommitting(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result) => result;
    public ValueTask<InterceptionResult> TransactionCommittingAsync(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public InterceptionResult TransactionRollingBack(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result) => result;
    public ValueTask<InterceptionResult> TransactionRollingBackAsync(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public InterceptionResult CreatingSavepoint(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result) => result;
    public void CreatedSavepoint(DbTransaction transaction, TransactionEventData eventData) { }
    public ValueTask<InterceptionResult> CreatingSavepointAsync(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public Task CreatedSavepointAsync(DbTransaction transaction, TransactionEventData eventData, CancellationToken ct = default) => Task.CompletedTask;
    public InterceptionResult RollingBackToSavepoint(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result) => result;
    public void RolledBackToSavepoint(DbTransaction transaction, TransactionEventData eventData) { }
    public ValueTask<InterceptionResult> RollingBackToSavepointAsync(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public Task RolledBackToSavepointAsync(DbTransaction transaction, TransactionEventData eventData, CancellationToken ct = default) => Task.CompletedTask;
    public InterceptionResult ReleasingSavepoint(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result) => result;
    public void ReleasedSavepoint(DbTransaction transaction, TransactionEventData eventData) { }
    public ValueTask<InterceptionResult> ReleasingSavepointAsync(DbTransaction transaction, TransactionEventData eventData, InterceptionResult result, CancellationToken ct = default) => ValueTask.FromResult(result);
    public Task ReleasedSavepointAsync(DbTransaction transaction, TransactionEventData eventData, CancellationToken ct = default) => Task.CompletedTask;
    public void TransactionFailed(DbTransaction transaction, TransactionErrorEventData eventData) => _awaitingCommit.Clear();
    public Task TransactionFailedAsync(DbTransaction transaction, TransactionErrorEventData eventData, CancellationToken ct = default)
    {
        _awaitingCommit.Clear();
        return Task.CompletedTask;
    }
}

/// <summary>The notification as the app receives it over SignalR (same shape as the list endpoint).</summary>
public sealed record NotificationDto(
    Guid Id, string Type, string TitleAr, string TitleEn, string BodyAr, string BodyEn,
    string? Route, JsonElement? Data, bool IsRead, DateTime CreatedAt);

/// <summary>
/// Delivers saved notifications (spec 9.2, 10.2): a SignalR event to every running app of the
/// recipient (Windows toasts, live badges), and FCM to their Android and iOS devices in their
/// language, respecting their preferences. Invalid push tokens are removed.
/// </summary>
public sealed class NotificationDispatcher(
    NotificationQueue queue,
    IServiceScopeFactory scopes,
    IRealtime realtime,
    IPushSender push,
    ILogger<NotificationDispatcher> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var id in queue.Reader.ReadAllAsync(stoppingToken))
        {
            try
            {
                await DeliverAsync(id, stoppingToken);
            }
            catch (Exception error) when (error is not OperationCanceledException)
            {
                logger.LogError(error, "Delivering notification {Id} failed", id);
            }
        }
    }

    public async Task DeliverAsync(Guid id, CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var n = await db.Notifications.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct);
        if (n is null) return;

        await realtime.ToUserAsync(n.RecipientUserId, RealtimeEvents.Notification, ToDto(n));

        var user = await db.Users.AsNoTracking()
            .Where(u => u.Id == n.RecipientUserId && u.Status == "active")
            .Select(u => new { u.Locale, u.NotifyChat, u.NotifyReminders, u.NotifyShowPreview })
            .FirstOrDefaultAsync(ct);
        if (user is null) return;
        if (NotificationTypes.IsChat(n.Type) && !user.NotifyChat) return;
        if (NotificationTypes.IsReminder(n.Type) && !user.NotifyReminders) return;

        // FCM is not used on Windows or macOS desktop (spec 10.2): SignalR covers running apps.
        var tokens = await db.UserDevices.AsNoTracking()
            .Where(d => d.UserId == n.RecipientUserId && d.FcmToken != null && (d.Platform == "android" || d.Platform == "ios"))
            .Select(d => d.FcmToken!)
            .ToListAsync(ct);
        if (tokens.Count == 0) return;

        var arabic = user.Locale == "ar";
        var body = arabic ? n.BodyAr : n.BodyEn;
        // Chat text only when the recipient switched previews on (spec 10.1). Never stored in the row.
        if (NotificationTypes.IsChat(n.Type) && user.NotifyShowPreview && TryGetGuid(n.DataJson, "messageId") is { } messageId)
        {
            var text = await db.ChatMessages.AsNoTracking().Where(m => m.Id == messageId).Select(m => m.Text).FirstOrDefaultAsync(ct);
            if (!string.IsNullOrWhiteSpace(text)) body = text.Length > 120 ? text[..120] + "…" : text;
        }

        var data = new Dictionary<string, string> { ["notificationId"] = n.Id.ToString(), ["type"] = n.Type };
        if (n.Route is not null) data["route"] = n.Route;

        var invalid = await push.SendAsync(tokens, new PushMessage(arabic ? n.TitleAr : n.TitleEn, body, data), ct);
        if (invalid.Count > 0)
        {
            await db.UserDevices.Where(d => d.UserId == n.RecipientUserId && invalid.Contains(d.FcmToken!))
                .ExecuteUpdateAsync(u => u.SetProperty(d => d.FcmToken, (string?)null), ct);
        }
    }

    public static NotificationDto ToDto(Notification n) => new(
        n.Id, n.Type, n.TitleAr, n.TitleEn, n.BodyAr, n.BodyEn, n.Route,
        n.DataJson is null ? null : JsonDocument.Parse(n.DataJson).RootElement.Clone(),
        n.IsRead, n.CreatedAt);

    private static Guid? TryGetGuid(string? json, string property)
    {
        if (json is null) return null;
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.TryGetProperty(property, out var value) && value.TryGetGuid(out var id) ? id : null;
    }
}
