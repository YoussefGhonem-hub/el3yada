using El3yada.Api.Storage;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Records;

/// <summary>
/// Deletes medical files that were uploaded but never claimed by createRecord within 24 hours
/// (backend/docs/api-phase-3-files.md), so abandoned uploads don't take up storage. Runs every hour.
/// </summary>
public sealed class PendingUploadCleanup(IServiceScopeFactory scopes, TimeProvider time, ILogger<PendingUploadCleanup> logger)
    : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval, time);
        do
        {
            try
            {
                await RunOnceAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Cleaning expired uploads failed");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    /// <summary>Deletes every expired upload and its files. Returns how many.</summary>
    public async Task<int> RunOnceAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopes.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var storage = scope.ServiceProvider.GetRequiredService<IFileStorage>();
        var now = time.GetUtcNow().UtcDateTime;
        var expired = await db.PendingUploads.Where(u => u.ExpiresAt <= now).Take(500).ToListAsync(cancellationToken);
        foreach (var upload in expired)
        {
            foreach (var value in new[] { upload.Path, upload.ThumbPath })
            {
                if (StoragePath.TryParse(value, out var path))
                {
                    await storage.DeleteAsync(path, cancellationToken);
                }
            }

            db.PendingUploads.Remove(upload);
        }

        await db.SaveChangesAsync(cancellationToken);
        if (expired.Count > 0)
        {
            logger.LogInformation("Deleted {Count} expired uploads", expired.Count);
        }

        return expired.Count;
    }
}
