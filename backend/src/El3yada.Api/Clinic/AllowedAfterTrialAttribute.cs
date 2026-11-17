namespace El3yada.Api.Clinic;

/// <summary>
/// Marks the clinic endpoints that still answer after the clinic's free trial has ended (BR-T4): only
/// <c>GET /api/clinic/me</c>, so the app can draw A15. Every other clinic endpoint answers 403 <c>TRIAL_ENDED</c>
/// (<see cref="ClinicAttribute"/>).
/// </summary>
[AttributeUsage(AttributeTargets.Method)]
public sealed class AllowedAfterTrialAttribute : Attribute;
