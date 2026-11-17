using SkiaSharp;

namespace El3yada.Api.Storage;

/// <summary>Image thumbnails with SkiaSharp (MIT).</summary>
internal static class Thumbnailer
{
    /// <summary>A decoded bitmap above this (about 200 MB of memory) is refused, so a crafted image cannot exhaust memory.</summary>
    private const long MaxDecodedPixels = 50_000_000;

    private const int JpegQuality = 80;

    /// <summary>
    /// Decodes a JPEG, PNG or WebP image and returns a JPEG whose longest edge is at most
    /// <paramref name="maxEdge"/>, upright (EXIF orientation applied) and on a white background.
    /// </summary>
    public static byte[] CreateJpeg(Stream image, int maxEdge)
    {
        using var output = Render(image, maxEdge, SKColors.White);
        using var jpeg = output.Encode(SKEncodedImageFormat.Jpeg, JpegQuality) ?? throw Unreadable();
        return jpeg.ToArray();
    }

    /// <summary>
    /// The same, as a PNG that keeps transparency: for the prescription logo and signature (D22), which are drawn
    /// over the page and must stay sharp. Metadata is dropped.
    /// </summary>
    public static byte[] CreatePng(Stream image, int maxEdge)
    {
        using var output = Render(image, maxEdge, SKColors.Transparent);
        using var png = output.Encode(SKEncodedImageFormat.Png, 100) ?? throw Unreadable();
        return png.ToArray();
    }

    /// <summary>Decodes, scales to <paramref name="maxEdge"/> and turns upright, over <paramref name="background"/>.</summary>
    private static SKBitmap Render(Stream image, int maxEdge, SKColor background)
    {
        using var codec = SKCodec.Create(image) ?? throw Unreadable();
        var encoded = codec.Info;
        if (encoded.Width <= 0 || encoded.Height <= 0)
        {
            throw Unreadable();
        }

        // Scale while decoding where the codec can (JPEG: 1/2, 1/4, 1/8; WebP: any size), so large photos stay cheap.
        var scale = Math.Min(1f, (float)maxEdge / Math.Max(encoded.Width, encoded.Height));
        var decodeSize = codec.GetScaledDimensions(scale);
        if ((long)decodeSize.Width * decodeSize.Height > MaxDecodedPixels)
        {
            throw Unreadable();
        }

        var decodeInfo = new SKImageInfo(decodeSize.Width, decodeSize.Height, SKColorType.Rgba8888, SKAlphaType.Premul);
        using var decoded = new SKBitmap(decodeInfo);
        var result = codec.GetPixels(decodeInfo, decoded.GetPixels());
        if (result is not (SKCodecResult.Success or SKCodecResult.IncompleteInput))
        {
            throw Unreadable();
        }

        var (width, height) = Fit(encoded.Width, encoded.Height, maxEdge);
        using var resized = (width, height) == (decodeSize.Width, decodeSize.Height)
            ? null
            : decoded.Resize(
                new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Premul),
                new SKSamplingOptions(SKCubicResampler.Mitchell)) ?? throw Unreadable();
        var source = resized ?? decoded;

        var origin = codec.EncodedOrigin;
        var turned = origin is SKEncodedOrigin.LeftTop or SKEncodedOrigin.RightTop
            or SKEncodedOrigin.RightBottom or SKEncodedOrigin.LeftBottom;
        var output = new SKBitmap(new SKImageInfo(
            turned ? height : width, turned ? width : height, SKColorType.Rgba8888, SKAlphaType.Premul));
        using (var canvas = new SKCanvas(output))
        {
            canvas.Clear(background);
            var matrix = OriginMatrix(origin, width, height);
            canvas.SetMatrix(in matrix);
            // Quarter turns and flips land on whole pixels, so plain sampling is exact.
            canvas.DrawBitmap(source, 0, 0, SKSamplingOptions.Default);
        }

        return output;
    }

    private static (int Width, int Height) Fit(int width, int height, int maxEdge)
    {
        var longest = Math.Max(width, height);
        if (longest <= maxEdge)
        {
            return (width, height);
        }

        var scale = (double)maxEdge / longest;
        return (Math.Max(1, (int)Math.Round(width * scale)), Math.Max(1, (int)Math.Round(height * scale)));
    }

    /// <summary>Maps an image stored in EXIF orientation <paramref name="origin"/> to upright (Skia's SkEncodedOriginToMatrix).</summary>
    private static SKMatrix OriginMatrix(SKEncodedOrigin origin, float w, float h) => origin switch
    {
        SKEncodedOrigin.TopRight => new SKMatrix(-1, 0, w, 0, 1, 0, 0, 0, 1),
        SKEncodedOrigin.BottomRight => new SKMatrix(-1, 0, w, 0, -1, h, 0, 0, 1),
        SKEncodedOrigin.BottomLeft => new SKMatrix(1, 0, 0, 0, -1, h, 0, 0, 1),
        SKEncodedOrigin.LeftTop => new SKMatrix(0, 1, 0, 1, 0, 0, 0, 0, 1),
        SKEncodedOrigin.RightTop => new SKMatrix(0, -1, h, 1, 0, 0, 0, 0, 1),
        SKEncodedOrigin.RightBottom => new SKMatrix(0, -1, h, -1, 0, w, 0, 0, 1),
        SKEncodedOrigin.LeftBottom => new SKMatrix(0, 1, 0, -1, 0, w, 0, 0, 1),
        _ => SKMatrix.Identity,
    };

    private static FileStorageException Unreadable() =>
        new(ErrorCodes.FileContentInvalid, "The image cannot be read.");
}
