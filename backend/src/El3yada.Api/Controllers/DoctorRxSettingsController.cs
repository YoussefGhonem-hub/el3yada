using System.Text.RegularExpressions;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// D22 prescription header and print settings (BR-RX4, BR-RX5, 6.4.1). Every field is replaced. <c>custom</c>
/// paper [S] needs both sizes; with A5 or A4 they are cleared. Margins are used in pre-printed paper mode.
/// </summary>
public sealed partial record UpdateRxSettingsRequest(
    string? Language, string? AccentColor, string? PaperSize, decimal? CustomWidthMm, decimal? CustomHeightMm,
    bool? Preprinted, decimal? MarginTopMm, decimal? MarginBottomMm, string? FooterText)
{
    [GeneratedRegex(@"^#[0-9A-Fa-f]{6}\z", RegexOptions.CultureInvariant)]
    public static partial Regex ColorPattern();
}

public sealed class UpdateRxSettingsRequestValidator : AbstractValidator<UpdateRxSettingsRequest>
{
    public UpdateRxSettingsRequestValidator()
    {
        RuleFor(x => x.Language).Required().OneOf("ar", "en");
        RuleFor(x => x.AccentColor).Required()
            .Must(color => color is null || UpdateRxSettingsRequest.ColorPattern().IsMatch(color))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("A colour like #0F4C45.");
        RuleFor(x => x.PaperSize).Required().OneOf(RxPaper.A5, RxPaper.A4, RxPaper.Custom);
        RuleFor(x => x.CustomWidthMm)
            .Must((x, width) => x.PaperSize != RxPaper.Custom || width is not null)
            .WithErrorCode(ErrorCodes.Required).WithMessage("Enter the paper width.")
            .InclusiveBetween(90, 300).WithErrorCode(ErrorCodes.OutOfRange).When(x => x.CustomWidthMm is not null);
        RuleFor(x => x.CustomHeightMm)
            .Must((x, height) => x.PaperSize != RxPaper.Custom || height is not null)
            .WithErrorCode(ErrorCodes.Required).WithMessage("Enter the paper height.")
            .InclusiveBetween(120, 420).WithErrorCode(ErrorCodes.OutOfRange).When(x => x.CustomHeightMm is not null);
        RuleFor(x => x.Preprinted).NotNull().WithErrorCode(ErrorCodes.Required);
        RuleFor(x => x.MarginTopMm).InclusiveBetween(0, 100).WithErrorCode(ErrorCodes.OutOfRange).When(x => x.MarginTopMm is not null);
        RuleFor(x => x.MarginBottomMm).InclusiveBetween(0, 100).WithErrorCode(ErrorCodes.OutOfRange).When(x => x.MarginBottomMm is not null);
        RuleFor(x => x.FooterText).MaxChars(300);
    }
}

public static class RxPaper
{
    public const string A5 = "A5";
    public const string A4 = "A4";
    public const string Custom = "custom";
}

public sealed record RxImageKindRequest(string? Kind);

public sealed class RxImageKindRequestValidator : AbstractValidator<RxImageKindRequest>
{
    public RxImageKindRequestValidator() => RuleFor(x => x.Kind).Required().OneOf("logo", "signature");
}

public sealed record RxSettingsView(
    string Language, string AccentColor, string PaperSize, decimal? CustomWidthMm, decimal? CustomHeightMm, bool Preprinted,
    decimal? MarginTopMm, decimal? MarginBottomMm, string? FooterText, bool HasLogo, bool HasSignature, DateTime UpdatedAt);

/// <summary>
/// D22: the prescription header and print settings, and the logo and signature images. Doctor only (BR-AS5),
/// also while suspended (settings, BR-G5). The app reads these to build the PDF (6.4.1).
/// </summary>
[ApiController]
[Route("api/doctor")]
[Clinic(DoctorOnly = true)]
public sealed class DoctorRxSettingsController(AppDbContext db, IFileStorage storage, Auditor auditor, TimeProvider time) : ControllerBase
{
    /// <summary>A logo or signature is at most 2 MB as uploaded.</summary>
    public const long ImageMaxBytes = 2 * 1024 * 1024;

    /// <summary>Stored at most 1000 px on the long edge: sharp at 300 dpi on a 30 mm header, small on disk.</summary>
    public const int ImageMaxEdge = 1000;

    [HttpGet("rxSettings")]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await LoadAsync(HttpContext.Clinic().DoctorId, cancellationToken));

    [HttpPost("updateRxSettings")]
    public async Task<IActionResult> Update(UpdateRxSettingsRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var doctor = await db.Doctors.SingleAsync(d => d.UserId == caller.DoctorId, cancellationToken);
        var custom = request.PaperSize == RxPaper.Custom;
        var fields = new List<string>();
        void Set<T>(T current, T value, string name, Action<T> apply)
        {
            if (!EqualityComparer<T>.Default.Equals(current, value))
            {
                apply(value);
                fields.Add(name);
            }
        }

        Set(doctor.RxLanguage, request.Language!, "language", v => doctor.RxLanguage = v);
        Set(doctor.RxAccentColor, request.AccentColor!.ToUpperInvariant(), "accentColor", v => doctor.RxAccentColor = v);
        Set(doctor.RxPaperSize, request.PaperSize!, "paperSize", v => doctor.RxPaperSize = v);
        Set(doctor.RxCustomWidthMm, custom ? Round(request.CustomWidthMm) : null, "customWidthMm", v => doctor.RxCustomWidthMm = v);
        Set(doctor.RxCustomHeightMm, custom ? Round(request.CustomHeightMm) : null, "customHeightMm", v => doctor.RxCustomHeightMm = v);
        Set(doctor.RxPreprinted, request.Preprinted!.Value, "preprinted", v => doctor.RxPreprinted = v);
        Set(doctor.RxMarginTopMm, Round(request.MarginTopMm), "marginTopMm", v => doctor.RxMarginTopMm = v);
        Set(doctor.RxMarginBottomMm, Round(request.MarginBottomMm), "marginBottomMm", v => doctor.RxMarginBottomMm = v);
        Set(doctor.RxFooterText, Text.TrimToNull(request.FooterText), "footerText", v => doctor.RxFooterText = v);
        if (fields.Count > 0)
        {
            doctor.UpdatedAt = time.GetUtcNow().UtcDateTime;
            auditor.AddClinic(caller, AuditActions.RxSettingsUpdated, AuditTargets.Doctor, doctor.UserId, new { fields });
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(await LoadAsync(doctor.UserId, cancellationToken));
    }

    /// <summary>
    /// <c>multipart/form-data</c>: <c>kind</c> (<c>logo</c> or <c>signature</c>) and <c>file</c> (JPEG, PNG or WebP,
    /// ≤ 2 MB). Saved as a PNG that keeps transparency, upright, at most 1000 px, without metadata.
    /// </summary>
    [HttpPost("uploadRxImage")]
    [RequestSizeLimit(ImageMaxBytes + (512 * 1024))]
    [RequestFormLimits(MultipartBodyLengthLimit = ImageMaxBytes + (512 * 1024))]
    public async Task<IActionResult> UploadImage(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (!Request.HasFormContentType)
        {
            return this.Problem(StatusCodes.Status415UnsupportedMediaType, ErrorCodes.UnsupportedMediaType, "Send multipart/form-data.");
        }

        IFormCollection form;
        try
        {
            form = await Request.ReadFormAsync(cancellationToken);
        }
        catch (Exception ex) when (ex is InvalidDataException or BadHttpRequestException)
        {
            return this.Problem(StatusCodes.Status413PayloadTooLarge, ErrorCodes.RequestTooLarge, "The request is too large.");
        }

        if (ImageOf(form["kind"].ToString()) is not { } image)
        {
            return ValidationProblems.Field(HttpContext, "kind", ErrorCodes.InvalidValue, "logo or signature.");
        }

        var file = form.Files.GetFile("file");
        if (file is null || file.Length == 0)
        {
            return ValidationProblems.Field(HttpContext, "file", ErrorCodes.Required, "Choose an image.");
        }

        if (file.Length > ImageMaxBytes)
        {
            return ValidationProblems.Field(HttpContext, "file", ErrorCodes.FileTooLarge, "The image is larger than 2 MB.");
        }

        var header = new byte[FileTypes.SignatureLength];
        await using (var peek = file.OpenReadStream())
        {
            var read = await peek.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
            if (!FileTypes.IsImage(FileTypes.Detect(header.AsSpan(0, read))))
            {
                return ValidationProblems.Field(HttpContext, "file", ErrorCodes.FileTypeNotAllowed, "Use a JPEG, PNG or WebP image.");
            }
        }

        byte[] png;
        try
        {
            await using var content = file.OpenReadStream();
            png = Thumbnailer.CreatePng(content, ImageMaxEdge);
        }
        catch (FileStorageException ex)
        {
            return ValidationProblems.Field(HttpContext, "file", ex.Code, ex.Message);
        }

        var path = StoragePath.DoctorBranding(caller.DoctorId, image);
        using (var stream = new MemoryStream(png, writable: false))
        {
            await storage.SaveAsync(path, stream, FileTypes.Png, cancellationToken: cancellationToken);
        }

        var doctor = await db.Doctors.SingleAsync(d => d.UserId == caller.DoctorId, cancellationToken);
        if (image == BrandingImage.Logo)
        {
            doctor.RxLogoPath = path.Value;
        }
        else
        {
            doctor.RxSignaturePath = path.Value;
        }

        doctor.UpdatedAt = time.GetUtcNow().UtcDateTime;
        auditor.AddClinic(
            caller, AuditActions.RxBrandingUpdated, AuditTargets.Doctor, doctor.UserId,
            new { image = Name(image), removed = false, sizeBytes = png.Length });
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await LoadAsync(doctor.UserId, cancellationToken));
    }

    /// <summary>The stored PNG, for the PDF and the D22 preview.</summary>
    [HttpGet("rxImage/{kind}")]
    public async Task<IActionResult> GetImage(string kind, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (ImageOf(kind) is not { } image)
        {
            return this.NotFoundProblem();
        }

        var stored = await db.Doctors.Where(d => d.UserId == caller.DoctorId)
            .Select(d => image == BrandingImage.Logo ? d.RxLogoPath : d.RxSignaturePath)
            .SingleAsync(cancellationToken);
        if (!StoragePath.TryParse(stored, out var path) || await storage.OpenReadAsync(path, cancellationToken) is not { } content)
        {
            return this.NotFoundProblem();
        }

        Response.Headers.CacheControl = "private, no-cache";
        Response.Headers.XContentTypeOptions = "nosniff";
        return new FileStreamResult(content.Content, FileTypes.Png);
    }

    [HttpPost("deleteRxImage")]
    public async Task<IActionResult> DeleteImage(RxImageKindRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var image = ImageOf(request.Kind)!.Value;
        var doctor = await db.Doctors.SingleAsync(d => d.UserId == caller.DoctorId, cancellationToken);
        var current = image == BrandingImage.Logo ? doctor.RxLogoPath : doctor.RxSignaturePath;
        if (current is null)
        {
            return Ok(await LoadAsync(doctor.UserId, cancellationToken));
        }

        if (image == BrandingImage.Logo)
        {
            doctor.RxLogoPath = null;
        }
        else
        {
            doctor.RxSignaturePath = null;
        }

        doctor.UpdatedAt = time.GetUtcNow().UtcDateTime;
        auditor.AddClinic(caller, AuditActions.RxBrandingUpdated, AuditTargets.Doctor, doctor.UserId, new { image = Name(image), removed = true });
        await db.SaveChangesAsync(cancellationToken);
        if (StoragePath.TryParse(current, out var path))
        {
            await storage.DeleteAsync(path, CancellationToken.None);
        }

        return Ok(await LoadAsync(doctor.UserId, cancellationToken));
    }

    private static BrandingImage? ImageOf(string? kind) => kind switch
    {
        "logo" => BrandingImage.Logo,
        "signature" => BrandingImage.Signature,
        _ => null,
    };

    private static string Name(BrandingImage image) => image == BrandingImage.Logo ? "logo" : "signature";

    private static decimal? Round(decimal? mm) => mm is { } value ? Math.Round(value, 1, MidpointRounding.AwayFromZero) : null;

    private Task<RxSettingsView> LoadAsync(Guid doctorId, CancellationToken cancellationToken) =>
        db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new RxSettingsView(
                d.RxLanguage, d.RxAccentColor, d.RxPaperSize, d.RxCustomWidthMm, d.RxCustomHeightMm, d.RxPreprinted,
                d.RxMarginTopMm, d.RxMarginBottomMm, d.RxFooterText, d.RxLogoPath != null, d.RxSignaturePath != null, d.UpdatedAt))
            .SingleAsync(cancellationToken);
}
