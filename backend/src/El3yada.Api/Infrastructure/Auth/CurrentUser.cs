using System.Security.Claims;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>
/// The caller, read from the access token. Only identity comes from the token:
/// status and permissions are always read from the database (spec 9.4), see
/// <see cref="ActiveAccountHandler"/>.
/// </summary>
public interface ICurrentUser
{
    bool IsAuthenticated { get; }

    /// <summary><c>Users.Id</c>. Throws when the request is anonymous.</summary>
    Guid UserId { get; }

    string Role { get; }

    /// <summary>For assistants: the doctor they work for.</summary>
    Guid? DoctorId { get; }
}

public sealed class HttpCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal? Principal => accessor.HttpContext?.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;

    public Guid UserId => TryGetUserId(Principal)
        ?? throw new InvalidOperationException("The request has no signed-in user.");

    public string Role => Principal?.FindFirstValue(AuthClaims.Role)
        ?? throw new InvalidOperationException("The request has no signed-in user.");

    public Guid? DoctorId => Guid.TryParse(Principal?.FindFirstValue(AuthClaims.DoctorId), out var id) ? id : null;

    internal static Guid? TryGetUserId(ClaimsPrincipal? principal) =>
        Guid.TryParse(principal?.FindFirstValue(AuthClaims.UserId), out var id) ? id : null;
}
