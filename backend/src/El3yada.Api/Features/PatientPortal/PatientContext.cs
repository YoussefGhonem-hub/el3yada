using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.PatientPortal;

/// <summary>
/// The signed-in patient's <c>Patients.Id</c>. Every patient query filters by it, so a patient
/// can only ever reach their own rows. A deleted patient (AD12) is refused even if a token survives.
/// </summary>
public sealed class PatientContext(AppDbContext db, ICurrentUser user)
{
    private Guid? _patientId;

    public async Task<Guid> GetPatientIdAsync(CancellationToken ct)
    {
        if (_patientId is { } cached) return cached;
        if (user.Role != Roles.Patient) throw ApiException.Forbidden();

        var id = await db.Patients.AsNoTracking()
            // Login itself is disabled through Users.Status (checked by ActiveAccountHandler).
            .Where(p => p.UserId == user.UserId && p.Status != "deleted")
            .Select(p => (Guid?)p.Id)
            .FirstOrDefaultAsync(ct);

        _patientId = id ?? throw ApiException.Forbidden(ErrorCodes.AccountDeleted);
        return id.Value;
    }
}
