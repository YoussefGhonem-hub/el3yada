using El3yada.Api.Analytics;
using El3yada.Api.Common;

namespace El3yada.Api.Billing;

/// <summary>
/// The scheduled jobs of spec 9.3 that run once a day (Africa/Cairo): <c>monthlyClose</c> (1st, 00:05),
/// <c>dailyBillingCheck</c> (00:10), <c>buildDailyMetrics</c> (02:30), <c>statsReconcile</c> [S] (03:00),
/// <c>accountErasure</c> (03:30, spec 6.17 BR-DEL4) and <c>trialReminders</c> [S] (10:00, so the push arrives in the
/// day; spec 6.16 BR-T6).
/// Each is idempotent, so a restart, a second server or a run missed during downtime changes nothing it should not.
/// </summary>
public sealed class BillingJobs(
    BillingService billing, DailyMetricsBuilder metrics, Doctors.TrialReminders trialReminders,
    Features.AccountDeletion.AccountDeletionJob accountErasure, TimeProvider time, JobStatus status,
    ILogger<BillingJobs> logger)
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

    /// <summary>
    /// <c>accountErasure</c>: erases the accounts whose deletion grace period has passed, except doctors who still owe an
    /// invoice (BR-DEL9). Returns the accounts erased.
    /// </summary>
    public Task<int> AccountErasureAsync(CancellationToken cancellationToken) => accountErasure.RunAsync(cancellationToken);

    /// <summary><c>trialReminders</c>: 3 days before the free trial ends and on its last day. Returns the notifications added.</summary>
    public Task<int> TrialRemindersAsync(CancellationToken cancellationToken) => trialReminders.SendAsync(cancellationToken);

    /// <summary>Runs one job and logs a failure without stopping the others (alerts watch for the error line, Phase 8).</summary>
    public async Task RunAsync(string name, Func<CancellationToken, Task<int>> job, CancellationToken cancellationToken)
    {
        try
        {
            var count = await job(cancellationToken);
            status.Succeeded(name, time.GetUtcNow().UtcDateTime);
            logger.LogInformation("Job {Job} done: {Count}", name, count);
        }
        catch (Exception error) when (error is not OperationCanceledException)
        {
            status.Failed(name, time.GetUtcNow().UtcDateTime);
            // One stable line to alert on (Phase 8): "ALERT billing-job".
            logger.LogError(error, "ALERT billing-job {Job} failed", name);
        }
    }
}

/// <summary>The last outcome of each scheduled job, read by <c>GET /api/health/jobs</c> so an uptime monitor can alert.</summary>
public sealed class JobStatus
{
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, (DateTime At, bool Ok)> _last = new();

    public void Succeeded(string job, DateTime at) => _last[job] = (at, true);

    public void Failed(string job, DateTime at) => _last[job] = (at, false);

    public IReadOnlyList<string> Failing => [.. _last.Where(x => !x.Value.Ok).Select(x => x.Key).Order()];

    public IReadOnlyDictionary<string, (DateTime At, bool Ok)> Snapshot => _last;
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
        ("accountErasure", new TimeOnly(3, 30)),
        ("trialReminders", new TimeOnly(10, 0)),
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
                        "trialReminders" => jobs.TrialRemindersAsync,
                        "accountErasure" => jobs.AccountErasureAsync,
                        _ => jobs.StatsReconcileAsync,
                    },
                    stoppingToken);
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
