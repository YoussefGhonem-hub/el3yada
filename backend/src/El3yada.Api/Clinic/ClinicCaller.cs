using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;
using AuditLogRow = El3yada.Data.Entities.AuditLog;

namespace El3yada.Api.Clinic;

/// <summary>
/// The doctor or assistant calling a clinic endpoint, read fresh from the database on every request (BR-AS4,
/// spec 9.4: an assistant's permissions and branches, and the doctor's status, are never taken from the token
/// or a cache). Set by <see cref="ClinicAttribute"/>; read it with <c>HttpContext.Clinic()</c>.
/// </summary>
public sealed record ClinicCaller
{
    public required Guid UserId { get; init; }

    public required bool IsDoctor { get; init; }

    /// <summary>The clinic: the doctor's own user ID, or the assistant's doctor.</summary>
    public required Guid DoctorId { get; init; }

    /// <summary>Doctors.Status of the clinic's doctor.</summary>
    public required string DoctorStatus { get; init; }

    /// <summary>The assistant's name, or null for the doctor.</summary>
    public string? AssistantName { get; init; }

    /// <summary>Doctor: every permission. Assistant: the switches that are on now.</summary>
    public required IReadOnlySet<string> Permissions { get; init; }

    /// <summary>The assistant works in every branch (BR-BR8). Always true for the doctor.</summary>
    public required bool AllBranches { get; init; }

    /// <summary>The assistant's assigned branches when <see cref="AllBranches"/> is false.</summary>
    public required IReadOnlySet<Guid> BranchIds { get; init; }

    public string Role => IsDoctor ? Roles.Doctor : Roles.Assistant;

    public bool IsSuspended => DoctorStatus == DoctorStatuses.Suspended;

    public bool Has(string permission) => IsDoctor || Permissions.Contains(permission);

    /// <summary>
    /// Whether the caller works in this branch (BR-AS13). Does not check that the branch is the doctor's:
    /// load branches with <c>DoctorId == caller.DoctorId</c>.
    /// </summary>
    public bool CanUseBranch(Guid branchId) => AllBranches || BranchIds.Contains(branchId);

    /// <summary>For branch-scoped lists (today's sessions, the board, bookings): null means every branch.</summary>
    public IReadOnlySet<Guid>? BranchScope => AllBranches ? null : BranchIds;

    /// <summary>Who did it, for <see cref="Auditor"/>.</summary>
    public AuditActor Actor => new(UserId, Role);

    /// <summary>Reads the caller, or null when the user is neither a doctor nor an assistant.</summary>
    public static async Task<ClinicCaller?> LoadAsync(AppDbContext db, Guid userId, string role, CancellationToken cancellationToken)
    {
        if (role == Roles.Doctor)
        {
            var status = await db.Doctors.AsNoTracking()
                .Where(d => d.UserId == userId)
                .Select(d => d.Status)
                .SingleOrDefaultAsync(cancellationToken);
            return status is null
                ? null
                : new ClinicCaller
                {
                    UserId = userId,
                    IsDoctor = true,
                    DoctorId = userId,
                    DoctorStatus = status,
                    Permissions = ClinicPermissions.All.ToHashSet(),
                    AllBranches = true,
                    BranchIds = new HashSet<Guid>(),
                };
        }

        if (role != Roles.Assistant)
        {
            return null;
        }

        var row = await db.Assistants.AsNoTracking()
            .Where(a => a.UserId == userId)
            .Select(a => new
            {
                Assistant = a,
                DoctorStatus = a.Doctor.Status,
                DoctorUserStatus = a.Doctor.User.Status,
                BranchIds = a.Branches.Select(b => b.Id).ToList(),
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null)
        {
            return null;
        }

        return new ClinicCaller
        {
            UserId = userId,
            IsDoctor = false,
            DoctorId = row.Assistant.DoctorId,
            // A disabled doctor user closes the clinic the same way a disabled doctor row does (BR-AS9).
            DoctorStatus = row.DoctorUserStatus == AccountStatuses.Active ? row.DoctorStatus : DoctorStatuses.Disabled,
            AssistantName = row.Assistant.FullName,
            Permissions = row.Assistant.Status == "active" ? ClinicPermissions.Of(row.Assistant) : new HashSet<string>(),
            AllBranches = row.Assistant.AllBranches,
            BranchIds = row.BranchIds.ToHashSet(),
            AssistantStatus = row.Assistant.Status,
            LastActiveAt = row.Assistant.LastActiveAt,
        };
    }

    internal string? AssistantStatus { get; init; }

    internal DateTime? LastActiveAt { get; init; }
}

public static class ClinicCallerExtensions
{
    internal const string ItemKey = "el3yada.clinic.caller";

    /// <summary>The caller checked by <see cref="ClinicAttribute"/> for this request.</summary>
    public static ClinicCaller Clinic(this HttpContext httpContext) =>
        httpContext.Items[ItemKey] as ClinicCaller
        ?? throw new InvalidOperationException("No clinic caller on this request: add [Clinic] to the endpoint.");

    /// <summary>
    /// An audit row in the clinic's activity log (D27, BR-AS10): the caller as actor, the clinic's doctor, and
    /// the patient when there is one. Every clinic write uses this, for the doctor's actions too.
    /// </summary>
    public static AuditLogRow AddClinic(
        this Auditor auditor, ClinicCaller caller, string action, string targetType, object? targetId,
        object? details = null, Guid? patientId = null) =>
        auditor.Add(action, targetType, targetId, details, doctorId: caller.DoctorId, patientId: patientId, actor: caller.Actor);
}
