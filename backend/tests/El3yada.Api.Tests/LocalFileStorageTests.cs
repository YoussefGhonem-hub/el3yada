using El3yada.Api.Configuration;
using El3yada.Api.Storage;
using Microsoft.Extensions.Hosting.Internal;
using SkiaSharp;

namespace El3yada.Api.Tests;

public sealed class LocalFileStorageTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "el3yada-api-tests", Guid.NewGuid().ToString("N"));
    private readonly Guid _doctor = Guid.NewGuid();
    private readonly Guid _patient = Guid.NewGuid();
    private readonly Guid _record = Guid.NewGuid();

    public void Dispose()
    {
        if (Directory.Exists(_root))
        {
            Directory.Delete(_root, recursive: true);
        }
    }

    private LocalFileStorage CreateStorage(int maxUploadMb = 200) => new(
        Microsoft.Extensions.Options.Options.Create(new StorageOptions { RootPath = _root, MaxUploadMb = maxUploadMb, ThumbnailMaxPx = 320 }),
        new HostingEnvironment { ContentRootPath = Path.GetTempPath() });

    private StoragePath Attachment(string contentType) =>
        StoragePath.MedicalAttachment(_doctor, _patient, _record, Guid.NewGuid(), contentType);

    private string[] FilesOnDisk() =>
        Directory.Exists(_root) ? Directory.GetFiles(_root, "*", SearchOption.AllDirectories) : [];

    private static byte[] Pdf(int size)
    {
        var bytes = new byte[size];
        "%PDF-1.7\n"u8.CopyTo(bytes);
        return bytes;
    }

    [Fact]
    public async Task Save_open_and_delete_round_trip()
    {
        var storage = CreateStorage();
        var path = Attachment("application/pdf");
        var bytes = Pdf(200_000);

        var saved = await storage.SaveAsync(path, new MemoryStream(bytes), "application/pdf");

        Assert.Equal(bytes.Length, saved.SizeBytes);
        Assert.Equal(Path.GetFullPath(Path.Combine(_root, path.Value)), Assert.Single(FilesOnDisk()));

        var opened = await storage.OpenReadAsync(path);
        Assert.NotNull(opened);
        await using (opened.Content)
        {
            using var copy = new MemoryStream();
            await opened.Content.CopyToAsync(copy);
            Assert.Equal(bytes, copy.ToArray());
            Assert.Equal(FileTypes.Pdf, opened.ContentType);
            Assert.Equal(bytes.Length, opened.SizeBytes);
        }

        Assert.True(await storage.DeleteAsync(path));
        Assert.Null(await storage.OpenReadAsync(path));
        Assert.False(await storage.DeleteAsync(path));
        Assert.Empty(FilesOnDisk());
    }

    [Fact]
    public async Task Saving_again_replaces_the_file()
    {
        var storage = CreateStorage();
        var path = StoragePath.DoctorBranding(_doctor, BrandingImage.Logo);

        await storage.SaveAsync(path, new MemoryStream(TestImages.Encode(40, 20, SKEncodedImageFormat.Png)), "image/png");
        var second = TestImages.Encode(80, 40, SKEncodedImageFormat.Png);
        await storage.SaveAsync(path, new MemoryStream(second), "image/png");

        Assert.Equal(second, await File.ReadAllBytesAsync(Assert.Single(FilesOnDisk())));
    }

    [Fact]
    public async Task A_file_over_the_limit_is_refused_and_leaves_nothing_behind()
    {
        var storage = CreateStorage();

        // A stream that cannot tell its length (like a request body) is cut off while it is read.
        var streamed = await Assert.ThrowsAsync<FileStorageException>(() => storage.SaveAsync(
            Attachment("application/pdf"), new UnknownLengthStream(Pdf(300_000)), "application/pdf", maxBytes: 100_000));
        // A stream with a known length is refused before anything is written.
        var known = await Assert.ThrowsAsync<FileStorageException>(() => storage.SaveAsync(
            Attachment("application/pdf"), new MemoryStream(Pdf(100_001)), "application/pdf", maxBytes: 100_000));

        Assert.Equal(ErrorCodes.FileTooLarge, streamed.Code);
        Assert.Equal(ErrorCodes.FileTooLarge, known.Code);
        Assert.Empty(FilesOnDisk());

        // Exactly at the limit is fine.
        await storage.SaveAsync(Attachment("application/pdf"), new UnknownLengthStream(Pdf(100_000)), "application/pdf", maxBytes: 100_000);
    }

    [Fact]
    public async Task Storage_MaxUploadMb_caps_a_larger_limit()
    {
        var storage = CreateStorage(maxUploadMb: 1);

        var error = await Assert.ThrowsAsync<FileStorageException>(() => storage.SaveAsync(
            Attachment("application/pdf"), new UnknownLengthStream(Pdf(1024 * 1024 + 1)), "application/pdf", maxBytes: 50L * 1024 * 1024));

        Assert.Equal(ErrorCodes.FileTooLarge, error.Code);
        Assert.Empty(FilesOnDisk());
    }

    [Fact]
    public async Task Content_that_does_not_match_its_type_is_refused()
    {
        var storage = CreateStorage();
        var html = "<html><script>alert(1)</script></html>"u8.ToArray();
        var png = TestImages.Encode(10, 10, SKEncodedImageFormat.Png);

        var renamedHtml = await Assert.ThrowsAsync<FileStorageException>(() =>
            storage.SaveAsync(Attachment("application/pdf"), new MemoryStream(html), "application/pdf"));
        var pngAsJpeg = await Assert.ThrowsAsync<FileStorageException>(() =>
            storage.SaveAsync(Attachment("image/jpeg"), new MemoryStream(png), "image/jpeg"));
        var empty = await Assert.ThrowsAsync<FileStorageException>(() =>
            storage.SaveAsync(Attachment("image/png"), new MemoryStream(), "image/png"));

        Assert.All([renamedHtml, pngAsJpeg, empty], error => Assert.Equal(ErrorCodes.FileContentInvalid, error.Code));
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, (await Assert.ThrowsAsync<FileStorageException>(() =>
            storage.SaveAsync(Attachment("image/png"), new MemoryStream(png), "text/html"))).Code);
        // A content type that does not match the path is a bug in the caller.
        await Assert.ThrowsAsync<ArgumentException>(() =>
            storage.SaveAsync(Attachment("image/png"), new MemoryStream(png), "application/pdf"));
        Assert.Empty(FilesOnDisk());
    }

    [Theory]
    [InlineData(SKEncodedImageFormat.Png, 1200, 800, 320, 213)]
    [InlineData(SKEncodedImageFormat.Jpeg, 800, 1200, 213, 320)]
    [InlineData(SKEncodedImageFormat.Jpeg, 4000, 3000, 320, 240)]
    [InlineData(SKEncodedImageFormat.Webp, 2000, 500, 320, 80)]
    [InlineData(SKEncodedImageFormat.Png, 100, 50, 100, 50)] // never enlarged
    public async Task Thumbnails_are_jpegs_with_the_longest_edge_at_most_ThumbnailMaxPx(
        SKEncodedImageFormat format, int width, int height, int thumbWidth, int thumbHeight)
    {
        var storage = CreateStorage();
        var contentType = format switch
        {
            SKEncodedImageFormat.Png => FileTypes.Png,
            SKEncodedImageFormat.Webp => FileTypes.Webp,
            _ => FileTypes.Jpeg,
        };
        var attachmentId = Guid.NewGuid();
        var image = StoragePath.MedicalAttachment(_doctor, _patient, _record, attachmentId, contentType);
        var thumbnail = StoragePath.MedicalAttachmentThumbnail(_doctor, _patient, _record, attachmentId);
        await storage.SaveAsync(image, new MemoryStream(TestImages.Encode(width, height, format)), contentType);

        var saved = await storage.CreateThumbnailAsync(image, thumbnail);

        Assert.Equal(FileTypes.Jpeg, saved.ContentType);
        using var codec = SKCodec.Create(Path.Combine(_root, thumbnail.Value));
        Assert.Equal(SKEncodedImageFormat.Jpeg, codec.EncodedFormat);
        Assert.Equal((thumbWidth, thumbHeight), (codec.Info.Width, codec.Info.Height));
    }

    [Theory]
    [InlineData(1, false, "red", "blue")] // upright: red on the left
    [InlineData(3, false, "blue", "red")] // upside down
    [InlineData(6, true, "red", "blue")] // camera turned right: the left side becomes the top
    [InlineData(8, true, "blue", "red")] // camera turned left: the left side becomes the bottom
    public async Task Thumbnails_follow_the_EXIF_orientation(int orientation, bool portrait, string firstHalf, string secondHalf)
    {
        var storage = CreateStorage();
        var image = Attachment(FileTypes.Jpeg);
        var thumbnail = StoragePath.ChatAttachmentThumbnail(Guid.NewGuid(), Guid.NewGuid());
        // 400 × 200, left half red and right half blue, as the camera stored it.
        var jpeg = TestImages.WithExifOrientation(TestImages.Encode(400, 200, SKEncodedImageFormat.Jpeg, halves: true), orientation);
        await storage.SaveAsync(image, new MemoryStream(jpeg), FileTypes.Jpeg);

        await storage.CreateThumbnailAsync(image, thumbnail);

        using var result = SKBitmap.Decode(Path.Combine(_root, thumbnail.Value));
        Assert.Equal(portrait ? (160, 320) : (320, 160), (result.Width, result.Height));
        // First half: left (landscape) or top (portrait).
        var first = portrait ? result.GetPixel(80, 40) : result.GetPixel(40, 80);
        var second = portrait ? result.GetPixel(80, 280) : result.GetPixel(280, 80);
        Assert.Equal(firstHalf, TestImages.ColorName(first));
        Assert.Equal(secondHalf, TestImages.ColorName(second));
    }

    [Fact]
    public async Task Transparent_areas_become_white()
    {
        var storage = CreateStorage();
        var image = Attachment(FileTypes.Png);
        var thumbnail = StoragePath.ChatAttachmentThumbnail(Guid.NewGuid(), Guid.NewGuid());
        await storage.SaveAsync(image, new MemoryStream(TestImages.Encode(64, 64, SKEncodedImageFormat.Png, transparent: true)), FileTypes.Png);

        await storage.CreateThumbnailAsync(image, thumbnail);

        using var result = SKBitmap.Decode(Path.Combine(_root, thumbnail.Value));
        Assert.Equal("white", TestImages.ColorName(result.GetPixel(32, 32)));
    }

    [Fact]
    public async Task Only_readable_images_get_thumbnails()
    {
        var storage = CreateStorage();
        var thumbnail = StoragePath.ChatAttachmentThumbnail(Guid.NewGuid(), Guid.NewGuid());
        var pdf = Attachment(FileTypes.Pdf);
        await storage.SaveAsync(pdf, new MemoryStream(Pdf(1000)), FileTypes.Pdf);
        // A JPEG signature followed by junk.
        var broken = Attachment(FileTypes.Jpeg);
        await storage.SaveAsync(broken, new MemoryStream([0xFF, 0xD8, 0xFF, .. new byte[500]]), FileTypes.Jpeg);

        await Assert.ThrowsAsync<ArgumentException>(() => storage.CreateThumbnailAsync(pdf, thumbnail));
        var error = await Assert.ThrowsAsync<FileStorageException>(() => storage.CreateThumbnailAsync(broken, thumbnail));
        Assert.Equal(ErrorCodes.FileContentInvalid, error.Code);
        Assert.False(File.Exists(Path.Combine(_root, thumbnail.Value)));
    }

    /// <summary>A read-only stream that cannot seek or tell its length, like an HTTP request body.</summary>
    private sealed class UnknownLengthStream(byte[] bytes) : Stream
    {
        private readonly MemoryStream _inner = new(bytes);

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) => _inner.Read(buffer, offset, count);
        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
}
