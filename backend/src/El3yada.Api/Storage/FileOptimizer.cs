using System.IO.Compression;
using SkiaSharp;

namespace El3yada.Api.Storage;

/// <summary>
/// Makes every uploaded medical file as small as it can be without losing what a doctor needs to read
/// (backend/docs/api-phase-3-files.md, "Making files smaller"). The server does it for every upload, so storage
/// stays small whatever the app sends:
/// <list type="bullet">
/// <item>Images: upright, longest edge at most <see cref="MaxImageEdge"/>, JPEG quality 80, no metadata (EXIF,
/// GPS). A JPEG that is already small keeps its own bytes, minus the metadata segments (lossless).</item>
/// <item>PDFs: kept as they are (the app builds scan PDFs small).</item>
/// <item>Other files (BR-F4): gzip when that saves at least <see cref="MinSaving"/>, unless the type is already
/// compressed (ZIP, Office, video, audio …).</item>
/// </list>
/// </summary>
public static class FileOptimizer
{
    /// <summary>An A4 page at about 220 dpi: small print stays sharp, while phone photos are often 4000+ px.</summary>
    public const int MaxImageEdge = 2560;

    /// <summary>A rewrite must save at least this share of the size, or the original is kept.</summary>
    public const double MinSaving = 0.10;

    /// <summary>Files smaller than this are never gzipped: the gain would be a few bytes.</summary>
    private const long MinCompressBytes = 4096;

    /// <summary>Already-compressed formats, by file extension: gzip would not shrink them.</summary>
    private static readonly HashSet<string> CompressedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        "zip", "gz", "tgz", "7z", "rar", "bz2", "xz", "zst", "docx", "xlsx", "pptx", "odt", "ods", "odp", "epub",
        "jar", "apk", "mp4", "m4v", "mov", "mkv", "webm", "avi", "wmv", "3gp", "mp3", "m4a", "aac", "ogg", "oga",
        "opus", "flac", "wma", "amr", "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "avif", "jxl", "pdf",
    };

    /// <summary>The same, by MIME type prefix, for files without an extension.</summary>
    private static readonly string[] CompressedTypePrefixes =
        ["video/", "audio/mpeg", "audio/mp4", "audio/ogg", "audio/aac", "image/jpeg", "image/png", "image/gif", "image/webp", "image/heic", "image/avif", "application/zip", "application/gzip", "application/vnd.openxmlformats"];

    /// <summary>
    /// What to store. <see cref="Content"/> is a temporary file that deletes itself when disposed.
    /// </summary>
    /// <param name="StoredType">The storage type: JPEG, PNG, WebP, PDF, <see cref="FileTypes.Binary"/> or <see cref="FileTypes.Gzip"/>.</param>
    /// <param name="MimeType">What users get when they download it (the real type, after any conversion).</param>
    /// <param name="SizeBytes">The size users download.</param>
    /// <param name="StoredSizeBytes">The size on disk.</param>
    /// <param name="Optimized">The bytes changed: re-encoded, stripped or compressed.</param>
    public sealed record Result(
        FileStream Content, string StoredType, string MimeType, long SizeBytes, long StoredSizeBytes, bool Optimized) : IAsyncDisposable
    {
        public ValueTask DisposeAsync() => Content.DisposeAsync();
    }

    /// <summary>
    /// Optimizes the file at <paramref name="sourcePath"/> (a temporary copy of the upload, left in place).
    /// <paramref name="detectedType"/> is the type read from the bytes (JPEG, PNG, WebP, PDF) or null for any
    /// other file, whose real type is <paramref name="mimeType"/>. Throws <see cref="FileStorageException"/>
    /// (FILE_CONTENT_INVALID) for an image that can't be decoded.
    /// </summary>
    public static async Task<Result> OptimizeAsync(
        string sourcePath, string? detectedType, string mimeType, string? fileName, CancellationToken cancellationToken)
    {
        var originalSize = new FileInfo(sourcePath).Length;
        if (detectedType is FileTypes.Jpeg or FileTypes.Png or FileTypes.Webp)
        {
            return await OptimizeImageAsync(sourcePath, detectedType, originalSize, cancellationToken);
        }

        if (detectedType == FileTypes.Pdf)
        {
            return new Result(OpenCopy(sourcePath), FileTypes.Pdf, FileTypes.Pdf, originalSize, originalSize, Optimized: false);
        }

        if (originalSize >= MinCompressBytes && IsCompressible(fileName, mimeType))
        {
            var gzip = NewTempFile();
            await using (var input = File.OpenRead(sourcePath))
            await using (var compressor = new GZipStream(gzip, CompressionLevel.SmallestSize, leaveOpen: true))
            {
                await input.CopyToAsync(compressor, cancellationToken);
            }

            if (gzip.Length <= originalSize * (1 - MinSaving))
            {
                gzip.Position = 0;
                return new Result(gzip, FileTypes.Gzip, mimeType, originalSize, gzip.Length, Optimized: true);
            }

            await gzip.DisposeAsync();
        }

        return new Result(OpenCopy(sourcePath), FileTypes.Binary, mimeType, originalSize, originalSize, Optimized: false);
    }

    /// <summary>Whether gzip is worth trying: not an already-compressed format.</summary>
    public static bool IsCompressible(string? fileName, string mimeType)
    {
        var extension = Path.GetExtension(fileName ?? "").TrimStart('.');
        if (extension.Length > 0)
        {
            return !CompressedExtensions.Contains(extension);
        }

        return !CompressedTypePrefixes.Any(prefix => mimeType.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    }

    private static async Task<Result> OptimizeImageAsync(string sourcePath, string type, long originalSize, CancellationToken cancellationToken)
    {
        int width, height;
        SKEncodedOrigin origin;
        await using (var probe = File.OpenRead(sourcePath))
        {
            using var codec = SKCodec.Create(probe)
                ?? throw new FileStorageException(ErrorCodes.FileContentInvalid, "The image cannot be read.");
            (width, height, origin) = (codec.Info.Width, codec.Info.Height, codec.EncodedOrigin);
        }

        byte[] jpeg;
        await using (var source = File.OpenRead(sourcePath))
        {
            jpeg = Thumbnailer.CreateJpeg(source, MaxImageEdge);
        }

        var fits = Math.Max(width, height) <= MaxImageEdge;
        var upright = origin == SKEncodedOrigin.TopLeft;
        var worthIt = jpeg.Length <= originalSize * (1 - MinSaving);

        // Already small and upright: keep the original pixels (no second lossy pass).
        if (fits && upright && !worthIt)
        {
            if (type == FileTypes.Jpeg)
            {
                var original = await File.ReadAllBytesAsync(sourcePath, cancellationToken);
                if (JpegMetadata.Strip(original) is { } stripped)
                {
                    return await FromBytesAsync(stripped, FileTypes.Jpeg, optimized: stripped.Length != original.Length, cancellationToken);
                }
            }
            else
            {
                // PNG and WebP carry no location data worth stripping; keep them when JPEG wouldn't help.
                return new Result(OpenCopy(sourcePath), type, type, originalSize, originalSize, Optimized: false);
            }
        }

        return await FromBytesAsync(jpeg, FileTypes.Jpeg, optimized: true, cancellationToken);
    }

    private static async Task<Result> FromBytesAsync(byte[] bytes, string type, bool optimized, CancellationToken cancellationToken)
    {
        var file = NewTempFile();
        await file.WriteAsync(bytes, cancellationToken);
        file.Position = 0;
        return new Result(file, type, type, bytes.Length, bytes.Length, optimized);
    }

    private static FileStream OpenCopy(string sourcePath) =>
        new(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read | FileShare.Delete, 81920, FileOptions.SequentialScan);

    private static FileStream NewTempFile() =>
        new(Path.Combine(Path.GetTempPath(), $"el3yada-{Guid.NewGuid():N}.tmp"), FileMode.CreateNew, FileAccess.ReadWrite,
            FileShare.None, 81920, FileOptions.DeleteOnClose);
}

/// <summary>Removes metadata segments from a JPEG without touching the image data (lossless).</summary>
public static class JpegMetadata
{
    /// <summary>
    /// The JPEG without APP1 (EXIF, XMP: camera, GPS location), APP13 (IPTC) and COM segments. JFIF, the colour
    /// profile (APP2) and every image segment stay. Null when the file isn't a JPEG this can walk safely.
    /// </summary>
    public static byte[]? Strip(ReadOnlySpan<byte> jpeg)
    {
        if (jpeg is not [0xFF, 0xD8, ..])
        {
            return null;
        }

        using var output = new MemoryStream(jpeg.Length);
        output.Write([0xFF, 0xD8]);
        var position = 2;
        while (position + 4 <= jpeg.Length)
        {
            if (jpeg[position] != 0xFF)
            {
                return null;
            }

            var marker = jpeg[position + 1];
            if (marker == 0xFF)
            {
                position++; // fill byte
                continue;
            }

            if (marker == 0xDA)
            {
                // Start of scan: the rest is image data.
                output.Write(jpeg[position..]);
                return output.ToArray();
            }

            var length = (jpeg[position + 2] << 8) | jpeg[position + 3];
            if (length < 2 || position + 2 + length > jpeg.Length)
            {
                return null;
            }

            var drop = marker is 0xE1 or 0xED or 0xFE;
            if (!drop)
            {
                output.Write(jpeg.Slice(position, 2 + length));
            }

            position += 2 + length;
        }

        return null;
    }
}
