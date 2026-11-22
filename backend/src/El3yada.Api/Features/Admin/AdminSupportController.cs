using El3yada.Api.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Features.Admin;

/// <summary>AD11 accounts support [S]. AD12 (account deletions) is in Features/AccountDeletion.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
[Produces("application/json")]
public sealed class AdminSupportController(AdminSupportService service) : ControllerBase
{
    /// <summary>AD11: patient and assistant accounts with this phone. Search by phone only.</summary>
    [HttpGet("accounts", Name = "searchAccounts")]
    public Task<AccountSearchResultDto> SearchAccounts([FromQuery] AccountSearchQuery query, CancellationToken ct) =>
        service.SearchAccountsAsync(query, ct);

    /// <summary>AD11: disable or enable login. Disabling signs the account out everywhere.</summary>
    [HttpPost("accounts/{userId:guid}/status", Name = "setAccountLoginStatus")]
    public async Task<IActionResult> SetLoginStatus(Guid userId, SetLoginStatusRequest request, CancellationToken ct)
    {
        await service.SetLoginStatusAsync(userId, request, ct);
        return NoContent();
    }
}
