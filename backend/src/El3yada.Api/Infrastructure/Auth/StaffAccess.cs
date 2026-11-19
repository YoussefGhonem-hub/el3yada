using El3yada.Api.Infrastructure.Errors;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>Assistant permission keys (spec 6.10). Doctors have all of them.</summary>
public enum StaffPermission
{
    PatientsManage, PatientsResetPassword, SessionsCreate, SessionsDelete, ClinicalView, ClinicalEditProfile,
    FilesManage, PrescriptionsPrint, PrescriptionsDraft, Chat, BillingView, BillingPay,
    AppointmentsView, AppointmentsManage, ScheduleManage, RevenueView, PricesManage,
}

/// <summary>
/// The caller acting for a clinic: the doctor, or one of the doctor's assistants. Built from the
/// database on every request (spec 9.4, BR-AS4), never from the token.
/// </summary>
public sealed class StaffContext
{
    public required Guid UserId { get; init; }
    public required Guid DoctorId { get; init; }
    public required bool IsDoctor { get; init; }
    public required string DisplayName { get; init; }

    /// <summary><c>Doctors.Status</c>: active or suspended (others never get a context).</summary>
    public required string DoctorStatus { get; init; }

    public required IReadOnlySet<StaffPermission> Permissions { get; init; }

    /// <summary>
    /// The branches the caller works in: all of the doctor's branches for the doctor and for an
    /// assistant with "all branches", otherwise the assistant's own (BR-AS13). Never another clinic's.
    /// </summary>
    public required IReadOnlySet<Guid> BranchIds { get; init; }

    /// <summary>The doctor, or an assistant assigned to every branch (also future ones).</summary>
    public required bool AllBranches { get; init; }

    public string Role => IsDoctor ? Roles.Doctor : Roles.Assistant;
    public bool IsSuspended => DoctorStatus == "suspended";

    public bool Has(StaffPermission permission) => IsDoctor || Permissions.Contains(permission);

    public bool CanSeeBranch(Guid branchId) => BranchIds.Contains(branchId);

    /// <summary>403 unless the caller has <paramref name="permission"/>.</summary>
    public StaffContext Require(StaffPermission permission) =>
        Has(permission) ? this : throw ApiException.Forbidden(ErrorCodes.PermissionDenied);

    public StaffContext RequireBranch(Guid branchId) =>
        CanSeeBranch(branchId) ? this : throw ApiException.Forbidden(ErrorCodes.PermissionDenied);

    /// <summary>Writes that a suspended doctor can't make (BR-G5): new chat messages, bookings, sessions.</summary>
    public StaffContext RequireNotSuspended() =>
        IsSuspended ? throw ApiException.Forbidden(ErrorCodes.DoctorSuspended) : this;
}

/// <summary>Loads <see cref="StaffContext"/> once per request. Phase 2 endpoints should use it too.</summary>
public sealed class StaffAccess(AppDbContext db, ICurrentUser user)
{
    private StaffContext? _context;

    public Task<StaffContext> GetAsync(CancellationToken ct) => GetForAsync(user.UserId, user.Role, ct);

    /// <summary>For callers without an HTTP request, such as SignalR hub methods.</summary>
    public async Task<StaffContext> GetForAsync(Guid userId, string role, CancellationToken ct)
    {
        if (_context is not null) return _context;

        if (role == Roles.Doctor)
        {
            var doctor = await db.Doctors.AsNoTracking()
                .Where(d => d.UserId == userId)
                .Select(d => new { d.FullName, d.Status })
                .FirstOrDefaultAsync(ct) ?? throw ApiException.Forbidden();
            EnsureClinicOpen(doctor.Status);
            return _context = new StaffContext
            {
                UserId = userId, DoctorId = userId, IsDoctor = true, DisplayName = doctor.FullName,
                DoctorStatus = doctor.Status, Permissions = new HashSet<StaffPermission>(),
                BranchIds = await DoctorBranchesAsync(userId, ct), AllBranches = true,
            };
        }

        if (role == Roles.Assistant)
        {
            var a = await db.Assistants.AsNoTracking()
                .Where(x => x.UserId == userId)
                .Select(x => new
                {
                    x.DoctorId, x.FullName, x.Status, DoctorStatus = x.Doctor.Status, x.AllBranches,
                    BranchIds = x.Branches.Select(b => b.Id).ToList(),
                    x.PatientsManage, x.PatientsResetPassword, x.SessionsCreate, x.SessionsDelete, x.ClinicalView,
                    x.ClinicalEditProfile, x.FilesManage, x.PrescriptionsPrint, x.PrescriptionsDraft, x.Chat,
                    x.BillingView, x.BillingPay, x.AppointmentsView, x.AppointmentsManage, x.ScheduleManage,
                    x.RevenueView, x.PricesManage,
                })
                .FirstOrDefaultAsync(ct) ?? throw ApiException.Forbidden();
            if (a.Status != "active") throw ApiException.Forbidden();
            EnsureClinicOpen(a.DoctorStatus);

            var permissions = new HashSet<StaffPermission>();
            void Add(bool on, StaffPermission p) { if (on) permissions.Add(p); }
            Add(a.PatientsManage, StaffPermission.PatientsManage);
            Add(a.PatientsResetPassword, StaffPermission.PatientsResetPassword);
            Add(a.SessionsCreate, StaffPermission.SessionsCreate);
            Add(a.SessionsDelete, StaffPermission.SessionsDelete);
            Add(a.ClinicalView, StaffPermission.ClinicalView);
            Add(a.ClinicalEditProfile, StaffPermission.ClinicalEditProfile);
            Add(a.FilesManage, StaffPermission.FilesManage);
            Add(a.PrescriptionsPrint, StaffPermission.PrescriptionsPrint);
            Add(a.PrescriptionsDraft, StaffPermission.PrescriptionsDraft);
            Add(a.Chat, StaffPermission.Chat);
            Add(a.BillingView, StaffPermission.BillingView);
            Add(a.BillingPay, StaffPermission.BillingPay);
            Add(a.AppointmentsView, StaffPermission.AppointmentsView);
            Add(a.AppointmentsManage, StaffPermission.AppointmentsManage);
            Add(a.ScheduleManage, StaffPermission.ScheduleManage);
            Add(a.RevenueView, StaffPermission.RevenueView);
            Add(a.PricesManage, StaffPermission.PricesManage);

            return _context = new StaffContext
            {
                UserId = userId, DoctorId = a.DoctorId, IsDoctor = false, DisplayName = a.FullName,
                DoctorStatus = a.DoctorStatus, Permissions = permissions,
                BranchIds = a.AllBranches ? await DoctorBranchesAsync(a.DoctorId, ct) : a.BranchIds.ToHashSet(),
                AllBranches = a.AllBranches,
            };
        }

        throw ApiException.Forbidden();
    }

    private async Task<IReadOnlySet<Guid>> DoctorBranchesAsync(Guid doctorId, CancellationToken ct) =>
        (await db.Branches.AsNoTracking().Where(b => b.DoctorId == doctorId).Select(b => b.Id).ToListAsync(ct)).ToHashSet();

    // Pending, rejected or disabled clinics: every request is refused (spec 9.4, BR-AS9).
    private static void EnsureClinicOpen(string doctorStatus)
    {
        if (doctorStatus is not ("active" or "suspended")) throw ApiException.Forbidden(ErrorCodes.ClinicInactive);
    }
}
