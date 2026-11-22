using El3yada.Api.Infrastructure.Auth;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.PatientPortal;

/// <summary>
/// P14: the patient's account. Deleting it is <c>requestAccountDeletion</c>, the same for every role
/// (Features/AccountDeletion, api-account-deletion.md).
/// </summary>
public sealed class PatientAccountService(
    AppDbContext db,
    PatientPortalService portal,
    ICurrentUser user)
{
    public async Task<PatientAccountDto> GetAccountAsync(CancellationToken ct)
    {
        var personal = await portal.GetPersonalInfoAsync(ct);
        var account = await db.Users.AsNoTracking()
            .Where(u => u.Id == user.UserId)
            .Select(u => new { u.Locale, u.ThemeMode, u.NotifyChat, u.NotifyReminders, u.NotifyShowPreview, u.AcceptedTermsAt })
            .FirstAsync(ct);

        return new PatientAccountDto(
            personal, account.Locale, account.ThemeMode, account.NotifyChat, account.NotifyReminders,
            account.NotifyShowPreview, account.AcceptedTermsAt);
    }
}
