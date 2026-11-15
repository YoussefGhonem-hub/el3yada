namespace El3yada.Api;

/// <summary>
/// Error codes the API returns. The app maps each code to an ARB message, so a code never changes once it ships.
/// Spec codes (CONSULTATION_REQUIRES_EXAM, the booking codes in 6.12.6 …) are added here with their endpoints.
/// </summary>
public static class ErrorCodes
{
    /// <summary>Not an Egyptian mobile number (spec section 11).</summary>
    public const string InvalidMobile = "INVALID_MOBILE";

    /// <summary>The file is larger than the upload limit.</summary>
    public const string FileTooLarge = "FILE_TOO_LARGE";

    /// <summary>The file type is not accepted (JPEG, PNG, WebP and PDF are).</summary>
    public const string FileTypeNotAllowed = "FILE_TYPE_NOT_ALLOWED";

    /// <summary>The file content does not match its type, or the image cannot be read.</summary>
    public const string FileContentInvalid = "FILE_CONTENT_INVALID";
}
