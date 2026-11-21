using El3yada.Api.Analytics;
using El3yada.Api.Common;

namespace El3yada.Api.Billing;

/// <summary>
/// The scheduled jobs of spec 9.3 that run once a day (Africa/Cairo): <c>monthlyClose</c> (1st, 00:05),
/// <c>dailyBillingCheck</c> (00:10), <c>buildDailyMetrics</c> (02:30) and <c>statsReconcile</c> [S] (03:00).
/// Each is idempotent, so a restart, a second server or a run missed during downtime changes nothing it should not.
/// </summary>
public sealed class BillingJobs(
    BillingService billing, DailyMetricsBuilder metrics, TimeProvider time, ILogger<BillingJobs> logger)
{
    private DateOnly Today => CairoTime.Today(time);

    /// <summary><c>monthlyClose</c> for the month before today's. Returns the invoices created.</summary>
    public async Task<int> MonthlyCloseAsync(CancellationToken cancellationToken)
    {
        var previous = Today.AddMonths(-1);
        return await billing.MonthlyCloseAsync(CairoTime.MonthKey(previous), cancellationToken);
    }

    /// <summary><c>dailyBillingCheck</c>. Returns the invoices marked overdue.</summary>
    public Task<int> DailyBillingCheckAsync(CancellationToken cancellationToken) => billing.DailyCheckAsync(cancellationToken);

    /// <summary><c>buildDailyMetrics</c>: yesterday, and any earlier day whose sessions changed in the last two days.</summary>
    public async Task<int> BuildDailyMetricsAsync(CancellationToken cancellationToken)
    {
        var rows = await metrics.BuildDayAsync(Today.AddDays(-1), null, cancellationToken);
        return rows + await metrics.RebuildChangedDaysAsync(TimeSpan.FromDays(2), cancellationToken);
    }

    /// <summary><c>statsReconcile</c> [S]: yesterday's counters against the sessions.</summary>
    public Task<int> StatsReconcileAsync(CancellationToken cancellationToken) =>
        billing.ReconcileStatsAsync(Today.AddDays(-1), cancellationToken);

    /// <summary>Runs one job and logs a failure without stopping the others (alerts watch for the error line, Phase 8).</summary>
    public async Task RunAsync(string name, Func<CancellationToken, Task<int>> job, CancellationToken cancellationToken)
    {
        try
        {
            var count = await job(cancellationToken);
            logger.LogInformation("Job {Job} done: {Count}", name, count);
        }
        catch (Exception error) when (error is not OperationCanceledException)
        {
            logger.LogError(error, "Billing job {Job} failed", name);
        }
    }
}

/// <summary>
/// Runs <see cref="BillingJobs"/> at their Cairo times: every few minutes it checks which jobs are due today and have
/// not run since this process started. Off with <c>Jobs:Enabled = false</c> (tests, which call the jobs directly).
/// </summary>
public sealed class BillingJobsHost(IServiceScopeFactory scopes, IConfiguration configuration, TimeProvider time) : BackgroundService
{
    private static readonly (string Name, TimeOnly At)[] Schedule =
    [
        ("monthlyClose", new TimeOnly(0, 5)),
        ("dailyBillingCheck", new TimeOnly(0, 10)),
        ("buildDailyMetrics", new TimeOnly(2, 30)),
        ("statsReconcile", new TimeOnly(3, 0)),
    ];

    private readonly Dictionary<string, DateOnly> _lastRun = [];

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!configuration.GetValue("Jobs:Enabled", true))
        {
            return;
        }

        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(configuration.GetValue("Jobs:BillingIntervalMinutes", 5)));
        do
        {
            var now = CairoTime.ToCairo(time.GetUtcNow().UtcDateTime);
            var today = DateOnly.FromDateTime(now);
            var clock = TimeOnly.FromDateTime(now);
            foreach (var (name, at) in Schedule)
            {
                if (clock < at || (_lastRun.TryGetValue(name, out var last) && last == today))
                {
                    continue;
                }

                _lastRun[name] = today;
                await using var scope = scopes.CreateAsyncScope();
                var jobs = scope.ServiceProvider.GetRequiredService<BillingJobs>();
                await jobs.RunAsync(
                    name,
                    name switch
                    {
                        "monthlyClose" => jobs.MonthlyCloseAsync,
                        "dailyBillingCheck" => jobs.DailyBillingCheckAsync,
                        "buildDailyMetrics" => jobs.BuildDailyMetricsAsync,
                        _ => jobs.StatsReconcileAsync,
                    },
                    stoppingToken);
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
