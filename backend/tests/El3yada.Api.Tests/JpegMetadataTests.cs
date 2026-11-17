using El3yada.Api.Storage;
using SkiaSharp;

namespace El3yada.Api.Tests;

/// <summary>Lossless metadata removal and the choices <see cref="FileOptimizer"/> makes (api-phase-3-files.md).</summary>
public sealed class JpegMetadataTests
{
    /// <summary>The offset of the first segment with this marker before the image data, or null.</summary>
    internal static int? FindSegment(byte[] jpeg, byte marker)
    {
        var position = 2;
        while (position + 4 <= jpeg.Length && jpeg[position] == 0xFF && jpeg[position + 1] != 0xDA)
        {
            if (jpeg[position + 1] == marker)
            {
                return position;
            }

            position += 2 + ((jpeg[position + 2] << 8) | jpeg[position + 3]);
        }

        return null;
    }

    [Fact]
    public void Strip_removes_exif_and_comments_and_keeps_the_image()
    {
        var original = TestImages.Encode(64, 48, SKEncodedImageFormat.Jpeg, halves: true);
        var withExif = TestImages.WithExifOrientation(original, 1);
        byte[] comment = [0xFF, 0xFE, 0x00, 0x07, (byte)'G', (byte)'P', (byte)'S', (byte)'!', 0x00];
        byte[] tagged = [.. withExif[..2], .. comment, .. withExif[2..]];

        var stripped = JpegMetadata.Strip(tagged);

        Assert.NotNull(stripped);
        Assert.Equal(original, stripped);
        Assert.Null(FindSegment(stripped, 0xE1));
        Assert.Null(FindSegment(stripped, 0xFE));
        using var bitmap = SKBitmap.Decode(stripped);
        Assert.Equal(64, bitmap.Width);
    }

    [Fact]
    public void Strip_refuses_what_is_not_a_walkable_jpeg()
    {
        Assert.Null(JpegMetadata.Strip([0x89, 0x50, 0x4E, 0x47]));
        Assert.Null(JpegMetadata.Strip([0xFF, 0xD8, 0x00, 0x00, 0x00, 0x00]));
        Assert.Null(JpegMetadata.Strip([0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF, 0x00]));
    }

    [Theory]
    [InlineData("results.csv", "text/csv", true)]
    [InlineData("series.dcm", "application/dicom", true)]
    [InlineData("scan.tiff", "image/tiff", true)]
    [InlineData("report.docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", false)]
    [InlineData("video.MP4", "video/mp4", false)]
    [InlineData("archive.zip", "application/zip", false)]
    [InlineData("", "video/mp4", false)]
    [InlineData("", "application/dicom", true)]
    public void Only_compressible_types_are_gzipped(string fileName, string mimeType, bool compressible) =>
        Assert.Equal(compressible, FileOptimizer.IsCompressible(fileName, mimeType));

    [Fact]
    public async Task A_small_png_that_jpeg_would_not_shrink_is_kept()
    {
        var png = TestImages.Encode(40, 40, SKEncodedImageFormat.Png);
        var source = Path.GetTempFileName();
        await File.WriteAllBytesAsync(source, png);
        try
        {
            await using var result = await FileOptimizer.OptimizeAsync(source, FileTypes.Png, FileTypes.Png, "dot.png", CancellationToken.None);

            Assert.Equal(FileTypes.Png, result.StoredType);
            Assert.False(result.Optimized);
            Assert.Equal(png.Length, result.StoredSizeBytes);
        }
        finally
        {
            File.Delete(source);
        }
    }
}
