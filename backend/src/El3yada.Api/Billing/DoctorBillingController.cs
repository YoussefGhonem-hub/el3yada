using System.Globalization;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Billing;

/// <summary>The invoices screens of the clinic (D18, D19, AS10): the doctor, or an assistant with <c>billingView</c>.</summary>
[ApiController]
[Route("api/billing")]
[Clinic(ClinicPermissions.BillingView)]
// A doctor in their account's grace period pays the invoices that hold its erasure back (BR-DEL9, A16).
[AllowWhilePendingDeletion]
public sealed class DoctorBillingController(
    AppDbContext db,
    IFileStorage storage,
    BillingService billing,
    NotificationWriter notifications,
    Auditor auditor,
    TimeProvider time) : ControllerBase
{
    /// <summary>
    /// D18, and the invoice card of D1: the doctor's invoices, newest month first. <c>attention</c> is the oldest invoice
    /// that still has to be paid (unpaid, rejected or overdue) and <c>underReview</c> the one with a payment waiting.
    /// </summary>
    [HttpGet("invoices")]
    public async Task<IActionResult> Invoices(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var rows = await db.Invoices.AsNoTracking()
            .Where(i => i.DoctorId == caller.DoctorId)
            .OrderByDescending(i => i.MonthKey)
            .Select(i => new InvoiceListItem(
                i.Id, i.MonthKey, i.PeriodStart, i.PeriodEnd, i.ExamCount, i.ConsultationCount, i.ExamAmountPiasters,
                i.ConsultationAmountPiasters, i.AdjustmentsPiasters, i.TotalDuePiasters, i.DueDate, i.Status,
                i.Status == InvoiceStatuses.Unpaid || i.Status == InvoiceStatuses.Rejected || i.Status == InvoiceStatuses.Overdue,
                i.PaidAt,
                i.IsFinal))
            .ToListAsync(cancellationToken);
        return Ok(new InvoiceListView(
            rows,
            rows.Where(r => r.CanPay).OrderBy(r => r.MonthKey).FirstOrDefault(),
            rows.FirstOrDefault(r => r.Status == InvoiceStatuses.PendingReview),
            rows.Where(r => InvoiceStatuses.Outstanding.Contains(r.Status)).Sum(r => r.TotalDuePiasters),
            await SuspensionAsync(caller.DoctorId, cancellationToken)));
    }

    /// <summary>D19: one invoice with its branch totals, adjustments, status timeline and payments.</summary>
    [HttpGet("invoices/{invoiceId:guid}")]
    public async Task<IActionResult> Invoice(Guid invoiceId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var invoice = await db.Invoices.AsNoTracking()
            .Where(i => i.Id == invoiceId && i.DoctorId == caller.DoctorId)
            .Select(i => new
            {
                i.Id, i.MonthKey, i.PeriodStart, i.PeriodEnd, i.ExamCount, i.ConsultationCount, i.ExamAmountPiasters,
                i.ConsultationAmountPiasters, i.AdjustmentsPiasters, i.TotalDuePiasters, i.DueDate, i.Status, i.PaidAt, i.PaidMethod,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (invoice is null)
        {
            return this.NotFoundProblem();
        }

        return Ok(await InvoiceViews.DetailAsync(db, invoice.Id, forAdmin: false, cancellationToken));
    }

    /// <summary>D20: where to send the money (InstaPay address, account name, the admin's instructions).</summary>
    [HttpGet("paymentInfo")]
    public async Task<IActionResult> PaymentInfo(CancellationToken cancellationToken) =>
        Ok(await db.AppSettings.AsNoTracking()
            .Select(s => new PaymentInfoView(s.InstapayAddress, s.InstapayAccountName, s.InstapayInstructionsAr, s.InstapayInstructionsEn))
            .SingleAsync(cancellationToken));

    /// <summary>
    /// <c>submitPayment</c> (BR-PAY1, BR-PAY2, D20): multipart with the screenshots (<c>screenshots</c>, 1 to 3 images of 10 MB
    /// or less) and the fields <c>amountPiasters</c>, <c>transferDate</c> (yyyy-MM-dd), and optionally <c>reference</c>,
    /// <c>senderName</c> and <c>note</c>. The invoice must be unpaid, rejected or overdue; it becomes <c>pendingReview</c>
    /// and the admins are notified. Allowed while the doctor is suspended: paying is how they get back (BR-G5).
    /// </summary>
    [HttpPost("invoices/{invoiceId:guid}/submitPayment")]
    [Clinic(ClinicPermissions.BillingPay)]
    [RequestSizeLimit(BillingLimits.MaxScreenshots * BillingLimits.ScreenshotMaxBytes + 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = BillingLimits.MaxScreenshots * BillingLimits.ScreenshotMaxBytes + 1024 * 1024)]
    public async Task<IActionResult> SubmitPayment(Guid invoiceId, CancellationToken cancellationToken)
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

        var today = CairoTime.Today(time);
        if (!int.TryParse(form["amountPiasters"], NumberStyles.None, CultureInfo.InvariantCulture, out var amount) || amount < 1)
        {
            return ValidationProblems.Field(HttpContext, "amountPiasters", ErrorCodes.Required, "Enter the amount transferred.");
        }

        if (amount > BillingLimits.MaxAmountPiasters)
        {
            return ValidationProblems.Field(HttpContext, "amountPiasters", ErrorCodes.OutOfRange, "The amount is too large.");
        }

        if (!DateOnly.TryParseExact(form["transferDate"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var transferDate))
        {
            return ValidationProblems.Field(HttpContext, "transferDate", ErrorCodes.Required, "Enter the transfer date.");
        }

        if (transferDate > today || transferDate < today.AddDays(-120))
        {
            return ValidationProblems.Field(HttpContext, "transferDate", ErrorCodes.OutOfRange, "The transfer date can't be in the future or older than 120 days.");
        }

        var reference = Text.TrimToNull(form["reference"]);
        var senderName = Text.TrimToNull(form["senderName"]);
        var note = Text.TrimToNull(form["note"]);
        if (reference?.Length > 100)
        {
            return ValidationProblems.Field(HttpContext, "reference", ErrorCodes.TooLong, "At most 100 characters.");
        }

        if (senderName?.Length > 60)
        {
            return ValidationProblems.Field(HttpContext, "senderName", ErrorCodes.TooLong, "At most 60 characters.");
        }

        if (note?.Length > 500)
        {
            return ValidationProblems.Field(HttpContext, "note", ErrorCodes.TooLong, "At most 500 characters.");
        }

        var files = form.Files.GetFiles("screenshots");
        if (files.Count == 0)
        {
            return ValidationProblems.Field(HttpContext, "screenshots", ErrorCodes.Required, "Attach a screenshot of the transfer.");
        }

        if (files.Count > BillingLimits.MaxScreenshots)
        {
            return ValidationProblems.Field(HttpContext, "screenshots", ErrorCodes.TooManyScreenshots, "At most 3 screenshots.");
        }

        var types = new List<string>();
        foreach (var file in files)
        {
            if (file.Length == 0)
            {
                return ValidationProblems.Field(HttpContext, "screenshots", ErrorCodes.Required, "A screenshot is empty.");
            }

            if (file.Length > BillingLimits.ScreenshotMaxBytes)
            {
                return ValidationProblems.Field(HttpContext, "screenshots", ErrorCodes.FileTooLarge, "A screenshot is larger than 10 MB.");
            }

            var header = new byte[FileTypes.SignatureLength];
            await using (var stream = file.OpenReadStream())
            {
                var read = await stream.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
                var detected = FileTypes.Detect(header.AsSpan(0, read));
                if (!FileTypes.IsImage(detected))
                {
                    return ValidationProblems.Field(HttpContext, "screenshots", ErrorCodes.FileTypeNotAllowed, "Screenshots must be JPEG, PNG or WebP images.");
                }

                types.Add(detected!);
            }
        }

        var saved = new List<StoragePath>();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            var invoice = await billing.LockInvoiceAsync(invoiceId, cancellationToken);
            if (invoice is null || invoice.DoctorId != caller.DoctorId)
            {
                return this.NotFoundProblem();
            }

            if (!InvoiceStatuses.Payable(invoice.Status))
            {
                return this.ConflictProblem(ErrorCodes.InvoiceNotPayable, "This invoice can't be paid now.")
                    .WithFields(("status", invoice.Status));
            }

            var now = time.GetUtcNow().UtcDateTime;
            var payment = new Payment
            {
                Id = Guid.NewGuid(),
                InvoiceId = invoice.Id,
                DoctorId = caller.DoctorId,
                AmountPiasters = amount,
                TransferDate = transferDate,
                Reference = reference,
                SenderName = senderName,
                Note = note,
                SubmittedBy = caller.UserId,
                SubmittedAt = now,
            };
            for (var i = 0; i < files.Count; i++)
            {
                var path = StoragePath.PaymentScreenshot(caller.DoctorId, invoice.Id, payment.Id, i + 1, types[i]);
                await using var stream = files[i].OpenReadStream();
                await storage.SaveAsync(path, stream, types[i], BillingLimits.ScreenshotMaxBytes, cancellationToken);
                saved.Add(path);
                payment.PaymentScreenshots.Add(new PaymentScreenshot
                {
                    Id = Guid.NewGuid(), PaymentId = payment.Id, Path = path.Value, SortOrder = (byte)(i + 1),
                });
            }

            db.Payments.Add(payment);
            invoice.Status = InvoiceStatuses.PendingReview;
            invoice.UpdatedAt = now;
            billing.AddHistory(invoice, InvoiceStatuses.PendingReview, null, caller.UserId);
            auditor.AddClinic(
                caller, AuditActions.PaymentSubmitted, AuditTargets.Payment, payment.Id,
                new { invoiceId = invoice.Id, monthKey = invoice.MonthKey, amountPiasters = amount, screenshots = files.Count });

            var doctorName = await db.Doctors.AsNoTracking().Where(d => d.UserId == caller.DoctorId).Select(d => d.FullName).SingleAsync(cancellationToken);
            foreach (var adminId in await billing.AdminIdsAsync(cancellationToken))
            {
                notifications.Add(adminId, BillingNotifications.Submitted(doctorName, invoice.MonthKey), "/admin/payments", new { paymentId = payment.Id, invoiceId = invoice.Id });
            }

            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return StatusCode(StatusCodes.Status201Created, new PaymentSubmittedView(payment.Id, invoice.Id, InvoiceStatuses.PendingReview));
        }
        catch (FileStorageException ex)
        {
            await DeleteQuietlyAsync(saved);
            return ValidationProblems.Field(HttpContext, "screenshots", ex.Code, ex.Message);
        }
        catch
        {
            await DeleteQuietlyAsync(saved);
            throw;
        }
    }

    /// <summary>One screenshot of one of the clinic's payments, to look at again in D19.</summary>
    [HttpGet("payments/{paymentId:guid}/screenshots/{number:int}")]
    public async Task<IActionResult> Screenshot(Guid paymentId, int number, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var path = await db.PaymentScreenshots.AsNoTracking()
            .Where(s => s.PaymentId == paymentId && s.SortOrder == number && s.Payment.DoctorId == caller.DoctorId)
            .Select(s => s.Path)
            .SingleOrDefaultAsync(cancellationToken);
        return await PaymentFiles.StreamAsync(this, storage, path, cancellationToken);
    }

    private async Task<SuspensionView?> SuspensionAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        var doctor = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new { d.Status, d.StatusReason })
            .SingleAsync(cancellationToken);
        return doctor.Status == "suspended"
            ? new SuspensionView(BillingSuspension.MonthOf(doctor.StatusReason), BillingSuspension.IsBilling(doctor.StatusReason))
            : null;
    }

    private async Task DeleteQuietlyAsync(IEnumerable<StoragePath> paths)
    {
        foreach (var path in paths)
        {
            try
            {
                await storage.DeleteAsync(path);
            }
            catch (IOException)
            {
            }
        }
    }
}

/// <summary>Streams a payment screenshot without caching or sniffing it (spec 9.4).</summary>
public static class PaymentFiles
{
    public static async Task<IActionResult> StreamAsync(
        ControllerBase controller, IFileStorage storage, string? path, CancellationToken cancellationToken)
    {
        if (path is null || await storage.OpenReadAsync(StoragePath.Parse(path), cancellationToken) is not { } file)
        {
            return controller.NotFoundProblem();
        }

        controller.Response.Headers.CacheControl = "private, no-store";
        controller.Response.Headers.XContentTypeOptions = "nosniff";
        return controller.File(file.Content, file.ContentType);
    }
}
