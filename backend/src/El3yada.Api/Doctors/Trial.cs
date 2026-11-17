namespace El3yada.Api.Doctors;

/// <summary>
/// The free trial (spec 6.16, backend/docs/api-free-trial.md): in the session, <c>clinic/me</c> and the admin's
/// registration views. Null when there is no trial: the service is active.
/// </summary>
/// <param name="EndsAt">Doctors.TrialEndsAt (UTC).</param>
/// <param name="Ended">The trial is over: clinic endpoints answer 403 <c>TRIAL_ENDED</c> and the app shows A15.</param>
/// <param name="DaysLeft">Whole days left, rounded up; 0 once ended.</param>
public sealed record TrialView(DateTime EndsAt, bool Ended, int DaysLeft)
{
    public static TrialView? Of(DateTime? endsAt, DateTime now)
    {
        if (endsAt is not { } end)
        {
            return null;
        }

        var ended = Trial.HasEnded(end, now);
        return new TrialView(end, ended, ended ? 0 : (int)Math.Ceiling((end - now).TotalDays));
    }
}

/// <summary>The trial rules, always checked with the server's clock (BR-T1–BR-T5).</summary>
public static class Trial
{
    /// <summary>Running: sessions carry no platform fee (BR-T3).</summary>
    public static bool IsRunning(DateTime? endsAt, DateTime now) => endsAt > now;

    /// <summary>Ended: the clinic is closed until the admin activates the service or extends the trial (BR-T4).</summary>
    public static bool HasEnded(DateTime? endsAt, DateTime now) => endsAt <= now;

    /// <summary>Set at approval (BR-T1).</summary>
    public static DateTime EndsAt(DateTime approvedAt, int trialDays) => approvedAt.AddDays(trialDays);

    /// <summary><c>extendDoctorTrial</c>: from the later of the current end and now, so an ended trial restarts today.</summary>
    public static DateTime Extend(DateTime endsAt, DateTime now, int days) => (endsAt > now ? endsAt : now).AddDays(days);

    public const int MinDays = 1;

    public const int MaxDays = 90;
}
