using System.Diagnostics.CodeAnalysis;
using System.Text.RegularExpressions;

namespace El3yada.Api.Storage;

/// <summary>
/// Where a file lives in the store: relative to Storage:RootPath, forward slashes, lower case, for example
/// <c>medical/{doctorId}/{patientId}/{recordId}/{attachmentId}.jpg</c>. This is the value saved in the
/// database Path columns. It is built only from IDs by the factory methods below, never from a user's
/// file name (that goes in the FileName column for display), or read back from the database with
/// <see cref="Parse"/>. Layout from spec section 8.
/// </summary>
public sealed partial record StoragePath
{
    /// <summary>The Path columns are NVARCHAR(400).</summary>
    public const int MaxLength = 400;

    private static readonly string[] Roots = ["medical", "prescriptions", "chat", "payments", "doctors", "uploads", "catalogs"];

    // Each segment starts with a letter or digit: no "", ".", "..", "\", ":" or spaces, so a path
    // can never leave the storage root. \z, not $: in .NET $ also matches before a final newline.
    [GeneratedRegex(@"^[a-z0-9][a-z0-9-]*(\.[a-z0-9]+)*\z", RegexOptions.CultureInvariant)]
    private static partial Regex SegmentPattern();

    private StoragePath(string value, string contentType)
    {
        Value = value;
        ContentType = contentType;
    }

    public string Value { get; }

    /// <summary>The content type that matches the file extension.</summary>
    public string ContentType { get; }

    public override string ToString() => Value;

    // medical/{doctorId}/{patientId}/{recordId}/{attachmentId}.{ext}
    public static StoragePath MedicalAttachment(
        Guid doctorId, Guid patientId, Guid recordId, Guid attachmentId, string contentType) =>
        Create($"medical/{Id(doctorId)}/{Id(patientId)}/{Id(recordId)}/{Id(attachmentId)}.{FileTypes.ExtensionFor(contentType)}");

    // medical/{doctorId}/{patientId}/{recordId}/{attachmentId}.thumb.jpg
    public static StoragePath MedicalAttachmentThumbnail(Guid doctorId, Guid patientId, Guid recordId, Guid attachmentId) =>
        Create($"medical/{Id(doctorId)}/{Id(patientId)}/{Id(recordId)}/{Id(attachmentId)}.thumb.jpg");

    // uploads/{doctorId}/{uploadId}.{ext}: a medical file waiting for createRecord (24 hours at most)
    public static StoragePath PendingUpload(Guid doctorId, Guid uploadId, string contentType) =>
        Create($"uploads/{Id(doctorId)}/{Id(uploadId)}.{FileTypes.ExtensionFor(contentType)}");

    // uploads/{doctorId}/{uploadId}.thumb.jpg
    public static StoragePath PendingUploadThumbnail(Guid doctorId, Guid uploadId) =>
        Create($"uploads/{Id(doctorId)}/{Id(uploadId)}.thumb.jpg");

    // prescriptions/{doctorId}/{patientId}/{rxId}.pdf
    public static StoragePath PrescriptionPdf(Guid doctorId, Guid patientId, Guid prescriptionId) =>
        Create($"prescriptions/{Id(doctorId)}/{Id(patientId)}/{Id(prescriptionId)}.pdf");

    // chat/{chatId}/{msgId}/file.{ext} (one attachment per message)
    public static StoragePath ChatAttachment(Guid chatId, Guid messageId, string contentType) =>
        Create($"chat/{Id(chatId)}/{Id(messageId)}/file.{FileTypes.ExtensionFor(contentType)}");

    // chat/{chatId}/{msgId}/thumb.jpg
    public static StoragePath ChatAttachmentThumbnail(Guid chatId, Guid messageId) =>
        Create($"chat/{Id(chatId)}/{Id(messageId)}/thumb.jpg");

    // payments/{doctorId}/{invoiceId}/{paymentId}/{n}.{ext}, n = 1–3, images only (spec 9.4 and 11)
    public static StoragePath PaymentScreenshot(
        Guid doctorId, Guid invoiceId, Guid paymentId, int number, string contentType)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(number, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(number, 3);
        if (!FileTypes.IsImage(contentType))
        {
            throw new FileStorageException(ErrorCodes.FileTypeNotAllowed, "Payment screenshots must be images.");
        }

        return Create($"payments/{Id(doctorId)}/{Id(invoiceId)}/{Id(paymentId)}/{number}.{FileTypes.ExtensionFor(contentType)}");
    }

    // doctors/{doctorId}/license/{fileId}.{ext}
    public static StoragePath DoctorLicense(Guid doctorId, Guid fileId, string contentType) =>
        Create($"doctors/{Id(doctorId)}/license/{Id(fileId)}.{FileTypes.ExtensionFor(contentType)}");

    // doctors/{doctorId}/branches/{branchId}/{photoId}.jpg: a D29 branch photo [S], at most 1600 px
    public static StoragePath BranchPhoto(Guid doctorId, Guid branchId, Guid photoId) =>
        Create($"doctors/{Id(doctorId)}/branches/{Id(branchId)}/{Id(photoId)}.jpg");

    // doctors/{doctorId}/branches/{branchId}/{photoId}.thumb.jpg
    public static StoragePath BranchPhotoThumbnail(Guid doctorId, Guid branchId, Guid photoId) =>
        Create($"doctors/{Id(doctorId)}/branches/{Id(branchId)}/{Id(photoId)}.thumb.jpg");

    // catalogs/v{n}.sqlite.gz: a published catalog version (spec 9.5, AD20)
    public static StoragePath Catalog(int versionNumber)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(versionNumber, 1);
        return Create($"catalogs/v{versionNumber}.sqlite.gz");
    }

    // doctors/{doctorId}/branding/{logo|signature}.png
    public static StoragePath DoctorBranding(Guid doctorId, BrandingImage image) =>
        Create($"doctors/{Id(doctorId)}/branding/{(image == BrandingImage.Logo ? "logo" : "signature")}.png");

    /// <summary>Reads back a path saved in the database. Throws <see cref="FormatException"/> for anything else.</summary>
    public static StoragePath Parse(string value) =>
        TryParse(value, out var path) ? path : throw new FormatException("Not a storage path.");

    public static bool TryParse([NotNullWhen(true)] string? value, [NotNullWhen(true)] out StoragePath? path)
    {
        path = null;
        if (string.IsNullOrEmpty(value) || value.Length > MaxLength)
        {
            return false;
        }

        var segments = value.Split('/');
        // Every path is root/…/file, except catalogs, which are root/file.
        var minSegments = segments[0] == "catalogs" ? 2 : 3;
        if (segments.Length < minSegments || !Roots.Contains(segments[0]) || !segments.All(SegmentPattern().IsMatch))
        {
            return false;
        }

        var fileName = segments[^1];
        var dot = fileName.LastIndexOf('.');
        if (dot < 0 || FileTypes.TypeForExtension(fileName[(dot + 1)..]) is not { } contentType)
        {
            return false;
        }

        path = new StoragePath(value, contentType);
        return true;
    }

    private static string Id(Guid id) =>
        id != Guid.Empty ? id.ToString("D") : throw new ArgumentException("An ID is required.", nameof(id));

    private static StoragePath Create(string value) =>
        TryParse(value, out var path) ? path : throw new InvalidOperationException($"Invalid storage path built: {value}");
}

public enum BrandingImage
{
    Logo,
    Signature,
}
