namespace El3yada.Api.Storage;

/// <summary>
/// The file types the API stores. Uploads are checked against the first four (JPEG, PNG, WebP, PDF), and anything
/// else is refused with FILE_TYPE_NOT_ALLOWED, except medical files: those may be any type (spec BR-F4) and are
/// stored as <see cref="Binary"/>, or <see cref="Gzip"/> when compressing them saves space. Their real type is
/// kept in the database.
/// </summary>
public static class FileTypes
{
    public const string Jpeg = "image/jpeg";
    public const string Png = "image/png";
    public const string Webp = "image/webp";
    public const string Pdf = "application/pdf";

    /// <summary>A medical file of any other type, stored as uploaded (<c>.bin</c>).</summary>
    public const string Binary = "application/octet-stream";

    /// <summary>A medical file stored gzip-compressed (<c>.gz</c>); downloads decompress it.</summary>
    public const string Gzip = "application/gzip";

    /// <summary>Types only the storage layer uses: never detected from an upload, never accepted by <see cref="Normalize"/>.</summary>
    private static readonly Dictionary<string, string> StoredOnlyExtensionByType = new(StringComparer.Ordinal)
    {
        [Binary] = "bin",
        [Gzip] = "gz",
    };

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
        ExtensionByType.Concat(StoredOnlyExtensionByType)
            .ToDictionary(pair => pair.Value, pair => pair.Key, StringComparer.Ordinal);

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
        NormalizeStored(contentType) is { } type
            ? ExtensionByType.GetValueOrDefault(type) ?? StoredOnlyExtensionByType[type]
            : throw new FileStorageException(ErrorCodes.FileTypeNotAllowed, "Only JPEG, PNG, WebP and PDF files are accepted.");

    /// <summary><see cref="Normalize"/>, plus the storage-only <see cref="Binary"/> and <see cref="Gzip"/>.</summary>
    internal static string? NormalizeStored(string? contentType)
    {
        if (Normalize(contentType) is { } type)
        {
            return type;
        }

        var bare = contentType?.Split(';', 2)[0].Trim().ToLowerInvariant();
        return bare is not null && StoredOnlyExtensionByType.ContainsKey(bare) ? bare : null;
    }

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
        Gzip => header is [0x1F, 0x8B, ..],
        // Any bytes: the real type is in the database (BR-F4).
        Binary => true,
        _ => false,
    };
}
