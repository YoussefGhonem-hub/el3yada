using SkiaSharp;

namespace El3yada.Api.Tests;

/// <summary>Small images made in memory for the storage tests.</summary>
internal static class TestImages
{
    /// <summary>A solid red image, or red on the left and blue on the right, or fully transparent.</summary>
    public static byte[] Encode(
        int width, int height, SKEncodedImageFormat format, bool halves = false, bool transparent = false)
    {
        using var bitmap = new SKBitmap(new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Premul));
        using (var canvas = new SKCanvas(bitmap))
        {
            canvas.Clear(transparent ? SKColors.Transparent : SKColors.Red);
            if (halves)
            {
                using var blue = new SKPaint { Color = SKColors.Blue };
                canvas.DrawRect(width / 2f, 0, width / 2f, height, blue);
            }
        }

        using var data = bitmap.Encode(format, 90);
        return data.ToArray();
    }

    /// <summary>Inserts an EXIF block with only the Orientation tag (1–8) after the JPEG start marker.</summary>
    public static byte[] WithExifOrientation(byte[] jpeg, int orientation)
    {
        byte[] app1 =
        [
            0xFF, 0xE1, 0x00, 0x22, // APP1, length 34
            0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
            0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // TIFF header, big endian, first IFD at 8
            0x00, 0x01, // 1 entry
            0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, (byte)orientation, 0x00, 0x00, // Orientation, SHORT, 1 value
            0x00, 0x00, 0x00, 0x00, // no next IFD
        ];
        return [.. jpeg[..2], .. app1, .. jpeg[2..]];
    }

    public static string ColorName(SKColor color) => color switch
    {
        { Red: > 200, Green: > 200, Blue: > 200 } => "white",
        { Red: > 150, Green: < 100, Blue: < 100 } => "red",
        { Red: < 100, Green: < 100, Blue: > 150 } => "blue",
        _ => $"other {color}",
    };
}
