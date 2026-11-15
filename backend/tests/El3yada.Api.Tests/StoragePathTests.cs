using El3yada.Api.Storage;

namespace El3yada.Api.Tests;

public class StoragePathTests
{
    private static readonly Guid A = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private static readonly Guid B = Guid.Parse("22222222-2222-2222-2222-222222222222");
    private static readonly Guid C = Guid.Parse("33333333-3333-3333-3333-333333333333");
    private static readonly Guid D = Guid.Parse("44444444-4444-4444-4444-444444444444");

    [Fact]
    public void Paths_follow_the_spec_layout_and_use_only_ids()
    {
        Assert.Equal(
            "medical/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/33333333-3333-3333-3333-333333333333/44444444-4444-4444-4444-444444444444.jpg",
            StoragePath.MedicalAttachment(A, B, C, D, "image/jpeg").Value);
        Assert.EndsWith("/44444444-4444-4444-4444-444444444444.thumb.jpg", StoragePath.MedicalAttachmentThumbnail(A, B, C, D).Value);
        Assert.Equal(
            "prescriptions/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/33333333-3333-3333-3333-333333333333.pdf",
            StoragePath.PrescriptionPdf(A, B, C).Value);
        Assert.Equal(
            "chat/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/file.png",
            StoragePath.ChatAttachment(A, B, "image/png").Value);
        Assert.Equal(
            "payments/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222/33333333-3333-3333-3333-333333333333/2.jpg",
            StoragePath.PaymentScreenshot(A, B, C, 2, "image/jpeg").Value);
        Assert.Equal(
            "doctors/11111111-1111-1111-1111-111111111111/license/22222222-2222-2222-2222-222222222222.pdf",
            StoragePath.DoctorLicense(A, B, "application/pdf").Value);
        Assert.Equal(
            "doctors/11111111-1111-1111-1111-111111111111/branding/signature.png",
            StoragePath.DoctorBranding(A, BrandingImage.Signature).Value);
    }

    [Fact]
    public void A_saved_path_reads_back_with_its_content_type()
    {
        var path = StoragePath.MedicalAttachment(A, B, C, D, "Image/WEBP");

        var parsed = StoragePath.Parse(path.Value);

        Assert.Equal(path, parsed);
        Assert.Equal(FileTypes.Webp, parsed.ContentType);
    }

    [Theory]
    [InlineData("../x.pdf")]
    [InlineData("medical/../../x.pdf")]
    [InlineData("medical/a/../../../windows/x.pdf")]
    [InlineData("medical/./a/x.pdf")]
    [InlineData("medical/a/..pdf")]
    [InlineData("/medical/a/x.pdf")]
    [InlineData("C:/medical/a/x.pdf")]
    [InlineData(@"medical\a\x.pdf")]
    [InlineData("medical//x.pdf")]
    [InlineData("medical/a/x.pdf/")]
    [InlineData("medical/a/x.pdf\n")]
    [InlineData("medical/a/X.pdf")]
    [InlineData("medical/a/my file.pdf")]
    [InlineData("medical/a/x.exe")]
    [InlineData("medical/a/x")]
    [InlineData("secrets/a/x.pdf")]
    [InlineData("medical/x.pdf")]
    [InlineData("")]
    public void Anything_else_is_refused(string value)
    {
        Assert.False(StoragePath.TryParse(value, out _));
        Assert.Throws<FormatException>(() => StoragePath.Parse(value));
    }

    [Fact]
    public void Ids_types_and_screenshot_numbers_are_checked()
    {
        Assert.Throws<ArgumentException>(() => StoragePath.PrescriptionPdf(Guid.Empty, B, C));
        Assert.Equal(ErrorCodes.FileTypeNotAllowed,
            Assert.Throws<FileStorageException>(() => StoragePath.MedicalAttachment(A, B, C, D, "text/html")).Code);
        Assert.Equal(ErrorCodes.FileTypeNotAllowed,
            Assert.Throws<FileStorageException>(() => StoragePath.PaymentScreenshot(A, B, C, 1, "application/pdf")).Code);
        Assert.Throws<ArgumentOutOfRangeException>(() => StoragePath.PaymentScreenshot(A, B, C, 4, "image/jpeg"));
    }
}
