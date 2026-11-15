namespace El3yada.Api.Auth;

/// <summary>Users.Role values (spec section 5).</summary>
public static class Roles
{
    public const string Admin = "admin";
    public const string Doctor = "doctor";
    public const string Assistant = "assistant";
    public const string Patient = "patient";
}

/// <summary>Users.AdminRole values: <c>superAdmin</c> manages admins, <c>admin</c> does everything else.</summary>
public static class AdminRoles
{
    public const string SuperAdmin = "superAdmin";
    public const string Admin = "admin";

    public static readonly string[] All = [SuperAdmin, Admin];
}

/// <summary>Users.Status values.</summary>
public static class AccountStatuses
{
    public const string Active = "active";
    public const string Disabled = "disabled";
}

/// <summary>Doctors.Status values.</summary>
public static class DoctorStatuses
{
    public const string PendingApproval = "pendingApproval";
    public const string Active = "active";
    public const string Rejected = "rejected";
    public const string Suspended = "suspended";
    public const string Disabled = "disabled";

    public static readonly string[] All = [PendingApproval, Active, Rejected, Suspended, Disabled];

    /// <summary>The clinic works (BR-AS9): its assistants may sign in.</summary>
    public static bool ClinicIsOpen(string? status) => status is Active or Suspended;
}

/// <summary>UserDevices.Platform values.</summary>
public static class Platforms
{
    public const string Android = "android";
    public const string Ios = "ios";
    public const string Windows = "windows";
    public const string Macos = "macos";

    public static readonly string[] All = [Android, Ios, Windows, Macos];

    /// <summary>Patients may not use the desktop app (spec section 4, A14).</summary>
    public static bool IsDesktop(string? platform) => platform is Windows or Macos;
}

/// <summary>Claims in the access token. Names are short and never mapped to WS-* URIs.</summary>
public static class ClaimNames
{
    public const string Subject = "sub";
    public const string Role = "role";
    public const string AdminRole = "adminRole";

    /// <summary>For a doctor, their own user ID; for an assistant, their doctor's (spec 9.1).</summary>
    public const string DoctorId = "doctorId";

    /// <summary>A hash of Users.SecurityStamp. A token whose stamp no longer matches is refused.</summary>
    public const string SecurityStamp = "sst";

    /// <summary>The refresh-token family (one sign-in on one device).</summary>
    public const string Session = "sid";

    public const string TokenId = "jti";
}

/// <summary>Authorization policy names.</summary>
public static class Policies
{
    /// <summary>Any admin (<c>admin</c> or <c>superAdmin</c>).</summary>
    public const string Admin = "admin";

    /// <summary>Super admins only: managing admin users (AD14).</summary>
    public const string SuperAdmin = "superAdmin";

    /// <summary>Doctor accounts, whatever their status. Status checks are per endpoint.</summary>
    public const string Doctor = "doctor";
}
