namespace El3yada.Api.Infrastructure.Auth;

/// <summary>Claim types carried in the access token (spec 9.1, 9.4).</summary>
public static class AuthClaims
{
    /// <summary>The user's id (<c>Users.Id</c>).</summary>
    public const string UserId = "sub";

    /// <summary><c>admin</c>, <c>doctor</c>, <c>assistant</c> or <c>patient</c>.</summary>
    public const string Role = "role";

    /// <summary>For admins only: <c>superAdmin</c> or <c>admin</c>.</summary>
    public const string AdminRole = "adminRole";

    /// <summary>For assistants only: the doctor they work for.</summary>
    public const string DoctorId = "doctorId";

    /// <summary>
    /// <c>Users.SecurityStamp</c> when the token was issued. A password change or a
    /// disabled account rotates the stamp, which rejects every older token at once.
    /// </summary>
    public const string SecurityStamp = "sstamp";
}

/// <summary>The values of <c>Users.Role</c>.</summary>
public static class Roles
{
    public const string Admin = "admin";
    public const string Doctor = "doctor";
    public const string Assistant = "assistant";
    public const string Patient = "patient";
}
