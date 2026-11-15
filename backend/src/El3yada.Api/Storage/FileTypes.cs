namespace El3yada.Api.Storage;

/// <summary>The file types the API stores. Anything else is refused with FILE_TYPE_NOT_ALLOWED.</summary>
public static class FileTypes
{
    public const string Jpeg = "image/jpeg";
    public const string Png = "image/png";
    public const string Webp = "image/webp";
    public const string Pdf = "application/pdf";

    /// <summary>Bytes needed to check every signature below (WebP: "RIFF", size, "WEBP").</summary>
    public const int SignatureLength = 12;

    private static readonly Dictionary<string, string> ExtensionByType = new(StringComparer.Ordinal)
    {
        [Jpeg] = "jpg",
        [Png] = "png",
        [Webp] = "webp",
        [Pdf] = "pdf",
    };

    private static readonly Dictionary<string, string> TypeByExtension =
        ExtensionByType.ToDictionary(pair => pair.Value, pair => pair.Key, StringComparer.Ordinal);

    /// <summary>
    /// <c>"Image/JPEG; q=1"</c> → <c>"image/jpeg"</c>, <c>"image/jpg"</c> → <c>"image/jpeg"</c>.
    /// Null when the type is not accepted.
    /// </summary>
    public static string? Normalize(string? contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return null;
        }

        var type = contentType.Split(';', 2)[0].Trim().ToLowerInvariant();
        if (type is "image/jpg" or "image/pjpeg")
        {
            type = Jpeg;
        }

        return ExtensionByType.ContainsKey(type) ? type : null;
    }

    public static bool IsImage(string? contentType) => Normalize(contentType) is Jpeg or Png or Webp;

    internal static string ExtensionFor(string contentType) =>
        Normalize(contentType) is { } type
            ? ExtensionByType[type]
            : throw new FileStorageException(ErrorCodes.FileTypeNotAllowed, "Only JPEG, PNG, WebP and PDF files are accepted.");

    internal static string? TypeForExtension(string extension) => TypeByExtension.GetValueOrDefault(extension);

    /// <summary>
    /// The accepted type whose signature the first bytes carry (at least <see cref="SignatureLength"/> bytes),
    /// or null. Upload endpoints use it instead of the part's Content-Type, which clients often send as
    /// application/octet-stream.
    /// </summary>
    public static string? Detect(ReadOnlySpan<byte> header)
    {
        foreach (var type in ExtensionByType.Keys)
        {
            if (HasSignature(type, header))
            {
                return type;
            }
        }

        return null;
    }

    /// <summary>True when the first bytes are the signature of the type, so a renamed file is refused.</summary>
    internal static bool HasSignature(string contentType, ReadOnlySpan<byte> header) => contentType switch
    {
        Jpeg => header is [0xFF, 0xD8, 0xFF, ..],
        Png => header is [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ..],
        // "RIFF" <4-byte size> "WEBP"
        Webp => header is [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ..],
        // "%PDF-"
        Pdf => header is [0x25, 0x50, 0x44, 0x46, 0x2D, ..],
        _ => false,
    };
}
