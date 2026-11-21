using El3yada.Api.Auth;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Paging;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Features.Admin;

/// <summary>AD11 accounts support [S] and AD12 account deletion requests [S].</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
[Produces("application/json")]
public sealed class AdminSupportController(AdminSupportService service) : ControllerBase
{
    /// <summary>AD12 queue. <c>status</c>: pending (default, oldest first), approved, rejected or all.</summary>
    [HttpGet("deletion-requests", Name = "getDeletionRequests")]
    public Task<PagedResult<AdminDeletionRequestDto>> GetDeletionRequests([FromQuery] DeletionRequestsQuery query, CancellationToken ct) =>
        service.GetDeletionRequestsAsync(query, ct);

    /// <summary><c>reviewDeletionRequest</c>: <c>decision</c> = approve or reject (reject needs a note).</summary>
    [HttpPost("deletion-requests/{id:guid}/review", Name = "reviewDeletionRequest")]
    public Task<DeletionRequestDto> ReviewDeletionRequest(Guid id, ReviewDeletionRequest request, CancellationToken ct) =>
        service.ReviewDeletionRequestAsync(id, request, ct);

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
