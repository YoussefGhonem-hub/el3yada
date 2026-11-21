using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Audit;
using El3yada.Api.Billing;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace El3yada.Api.Tests.Integration;

/// <summary>A clock stopped at one moment, for the jobs that depend on the Cairo date and time.</summary>
public sealed class StoppedClock(DateTimeOffset now) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => now;
}

public static partial class TestData
{
    /// <summary>A session saved on <paramref name="day"/> (Cairo), straight in the database.</summary>
    public static async Task<Guid> AddSessionAsync(
        IntegrationFactory factory, Guid doctorId, Guid patientId, DateOnly day, string type = "examination", int feePiasters = 3000,
        int patientFeePiasters = 30000, int? listPricePiasters = null, bool deleted = false, Guid? branchId = null, Guid? by = null)
    {
        var id = Guid.NewGuid();
        await WithDbAsync(factory, async db =>
        {
            var link = await db.DoctorPatients.SingleAsync(l => l.DoctorId == doctorId && l.PatientId == patientId);
            var branch = branchId ?? await db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.DefaultBranchId!.Value).SingleAsync();
            var at = CairoTime.StartUtc(day).AddHours(10);
            db.Sessions.Add(new Session
            {
                Id = id, DoctorId = doctorId, PatientId = patientId, LinkId = link.Id, BranchId = branch, Type = type,
                FeePiasters = feePiasters, PatientFeePiasters = patientFeePiasters, ListPricePiasters = listPricePiasters ?? patientFeePiasters,
                DayKey = day, MonthKey = CairoTime.MonthKey(day), CreatedBy = by ?? doctorId, CreatedByRole = "doctor",
                Deleted = deleted, DeletedAt = deleted ? at : null, DeletedBy = deleted ? doctorId : null, DeleteReason = deleted ? "خطأ في الإدخال" : null,
                CreatedAt = at, UpdatedAt = at,
            });
            await db.SaveChangesAsync();
        });
        return id;
    }

    public static async Task<(TestUser Doctor, Guid PatientId)> CreateDoctorWithPatientAsync(IntegrationFactory factory)
    {
        var doctor = await CreateDoctorAsync(factory);
        var (_, patientId) = await CreatePatientAsync(factory);
        await LinkAsync(factory, doctor.Id, patientId);
        // LinkAsync numbers the file 1 without moving the counter the next createPatient uses.
        await WithDbAsync(factory, db => db.Doctors.Where(d => d.UserId == doctor.Id).ExecuteUpdateAsync(set => set.SetProperty(d => d.NextFileNumber, 2)));
        return (doctor, patientId);
    }

    /// <summary>The billing service with its clock stopped at <paramref name="utcNow"/>, inside a scope the caller disposes.</summary>
    public static BillingService BillingAt(IServiceScope scope, DateTimeOffset utcNow)
    {
        var services = scope.ServiceProvider;
        return new BillingService(
            services.GetRequiredService<AppDbContext>(),
            services.GetRequiredService<NotificationWriter>(),
            services.GetRequiredService<Auditor>(),
            services.GetRequiredService<AccountStateCache>(),
            new StoppedClock(utcNow),
            NullLogger<BillingService>.Instance);
    }

    /// <summary>00:10 Cairo on <paramref name="day"/>, when dailyBillingCheck runs.</summary>
    public static DateTimeOffset DailyCheckTime(DateOnly day) => new(CairoTime.StartUtc(day).AddMinutes(10), TimeSpan.Zero);

    public static async Task<Guid> InvoiceIdAsync(IntegrationFactory factory, Guid doctorId, string monthKey) =>
        await WithDbAsync(factory, db => db.Invoices.Where(i => i.DoctorId == doctorId && i.MonthKey == monthKey).Select(i => i.Id).SingleAsync());

    /// <summary>The "October" of the spec's worked example, in a year that has passed: invoice due 7 November.</summary>
    public const string October = "2026-10";

    public static readonly DateOnly OctoberDay = new(2026, 10, 12);
}

/// <summary>
/// Phase 7 billing: month close (AC-6), the payment flow (AC-7), suspension and reactivation (AC-8), and the rule that a
/// payment under review protects the doctor (AC-9), plus the admin's invoice actions (BR-PAY4) and who may do what.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class BillingTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static readonly DateTimeOffset FirstOfNovember = new(CairoTime.StartUtc(new DateOnly(2026, 11, 1)).AddMinutes(5), TimeSpan.Zero);

    private async Task<(TestUser Doctor, Guid InvoiceId)> DoctorWithOctoberInvoiceAsync(int exams = 4, int consultations = 2)
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        for (var i = 0; i < exams; i++)
        {
            await TestData.AddSessionAsync(Factory, doctor.Id, patient, TestData.OctoberDay.AddDays(i), "examination", 3000);
        }

        for (var i = 0; i < consultations; i++)
        {
            await TestData.AddSessionAsync(Factory, doctor.Id, patient, TestData.OctoberDay.AddDays(i), "consultation", 1500);
        }

        await using var scope = Factory.CreateScope();
        await TestData.BillingAt(scope, FirstOfNovember).MonthlyCloseAsync(TestData.October, CancellationToken.None);
        return (doctor, await TestData.InvoiceIdAsync(Factory, doctor.Id, TestData.October));
    }

    private static MultipartFormDataContent PaymentForm(int amountPiasters, DateOnly? date = null, int screenshots = 1, string? reference = "IP-123")
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(amountPiasters.ToString()), "amountPiasters" },
            { new StringContent((date ?? CairoTime.Today(TimeProvider.System)).ToString("yyyy-MM-dd")), "transferDate" },
        };
        if (reference is not null)
        {
            form.Add(new StringContent(reference), "reference");
        }

        for (var i = 0; i < screenshots; i++)
        {
            var image = new ByteArrayContent(TestImages.Encode(8 + i, 8, SkiaSharp.SKEncodedImageFormat.Png));
            image.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            form.Add(image, "screenshots", $"shot{i}.png");
        }

        return form;
    }

    private async Task<HttpResponseMessage> SubmitAsync(HttpClient client, Guid invoiceId, int amount, int screenshots = 1)
    {
        using var form = PaymentForm(amount, screenshots: screenshots);
        return await client.PostAsync($"/api/billing/invoices/{invoiceId}/submitPayment", form);
    }

    // ---- AC-6 --------------------------------------------------------------------------------------------------

    [Fact]
    public async Task Month_close_makes_one_invoice_per_doctor_from_the_fee_snapshots_and_a_second_run_changes_nothing()
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var other = await TestData.AddBranchAsync(Factory, doctor.Id);
        // A fee change mid-month: the invoice sums the snapshots, not count × today's fee (BR-B5).
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 10, 3), "examination", 3000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 10, 20), "examination", 4000, branchId: other);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 10, 21), "consultation", 1500);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 10, 22), "consultation", 1500, deleted: true);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 11, 2), "examination", 3000);
        var quiet = await TestData.CreateDoctorAsync(Factory);
        await TestData.SetDoctorStatusAsync(Factory, quiet.Id, DoctorStatuses.Active);

        int created;
        await using (var scope = Factory.CreateScope())
        {
            created = await TestData.BillingAt(scope, FirstOfNovember).MonthlyCloseAsync(TestData.October, CancellationToken.None);
        }

        Assert.True(created >= 1);
        var invoice = await TestData.WithDbAsync(Factory, db => db.Invoices
            .Include(i => i.InvoiceBranchBreakdowns).Include(i => i.InvoiceStatusHistories)
            .SingleAsync(i => i.DoctorId == doctor.Id));
        Assert.Equal(TestData.October, invoice.MonthKey);
        Assert.Equal(2, invoice.ExamCount);
        Assert.Equal(1, invoice.ConsultationCount);
        Assert.Equal(7000, invoice.ExamAmountPiasters);
        Assert.Equal(1500, invoice.ConsultationAmountPiasters);
        Assert.Equal(8500, invoice.TotalDuePiasters);
        Assert.Equal(new DateOnly(2026, 10, 1), invoice.PeriodStart);
        Assert.Equal(new DateOnly(2026, 10, 31), invoice.PeriodEnd);
        Assert.Equal(new DateOnly(2026, 11, 7), invoice.DueDate);   // grace period 7 days
        Assert.Equal(InvoiceStatuses.Unpaid, invoice.Status);
        Assert.Equal(2, invoice.InvoiceBranchBreakdowns.Count);
        Assert.Equal(8500, invoice.InvoiceBranchBreakdowns.Sum(b => b.AmountPiasters));
        Assert.Single(invoice.InvoiceStatusHistories);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.Invoices.AnyAsync(i => i.DoctorId == quiet.Id)));
        Assert.Contains(await TestData.WithDbAsync(Factory, db => db.Notifications.Where(n => n.RecipientUserId == doctor.Id).ToListAsync()),
            n => n.Type == BillingNotifications.InvoiceCreated);

        await using (var again = Factory.CreateScope())
        {
            Assert.Equal(0, await TestData.BillingAt(again, FirstOfNovember).MonthlyCloseAsync(TestData.October, CancellationToken.None));
        }

        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.Invoices.CountAsync(i => i.DoctorId == doctor.Id)));
        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.InvoiceStatusHistories.CountAsync(h => h.InvoiceId == invoice.Id)));
    }

    [Fact]
    public async Task A_month_spent_in_the_trial_closes_as_no_charge_without_a_notification()
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, new DateOnly(2026, 10, 5), "examination", feePiasters: 0);
        await using (var scope = Factory.CreateScope())
        {
            await TestData.BillingAt(scope, FirstOfNovember).MonthlyCloseAsync(TestData.October, CancellationToken.None);
        }

        var invoice = await TestData.WithDbAsync(Factory, db => db.Invoices.SingleAsync(i => i.DoctorId == doctor.Id));
        Assert.Equal(InvoiceStatuses.NoCharge, invoice.Status);
        Assert.Equal(0, invoice.TotalDuePiasters);
        Assert.DoesNotContain(
            await TestData.WithDbAsync(Factory, db => db.Notifications.Where(n => n.RecipientUserId == doctor.Id).ToListAsync()),
            n => n.Type == BillingNotifications.InvoiceCreated);
    }

    // ---- AC-7 --------------------------------------------------------------------------------------------------

    [Fact]
    public async Task The_doctor_submits_a_screenshot_the_admin_rejects_with_a_reason_then_approves_the_second_try()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        // The due date is still ahead, so a rejection leaves the invoice rejected (after it, BR-G2 makes it overdue).
        await TestData.WithDbAsync(Factory, db => db.Invoices.Where(i => i.Id == invoiceId)
            .ExecuteUpdateAsync(set => set.SetProperty(i => i.DueDate, CairoTime.Today(TimeProvider.System).AddDays(10))));

        var submitted = await SubmitAsync(asDoctor, invoiceId, 15000, screenshots: 2);
        Assert.Equal(HttpStatusCode.Created, submitted.StatusCode);
        var firstPaymentId = (await Http.BodyAsync(submitted)).GetProperty("paymentId").GetGuid();

        var (_, detail) = await asDoctor.GetJsonAsync($"/api/billing/invoices/{invoiceId}");
        Assert.Equal(InvoiceStatuses.PendingReview, detail.Str("status"));
        Assert.False(detail.GetProperty("canPay").GetBoolean());
        Assert.Equal(2, detail.GetProperty("payments")[0].GetProperty("screenshots").GetInt32());
        // While it is under review the doctor can't submit again.
        Assert.Equal(HttpStatusCode.Conflict, (await SubmitAsync(asDoctor, invoiceId, 15000)).StatusCode);

        // AD7: the queue shows it, with the mismatch flag (15000 entered and due: no mismatch).
        var (_, queue) = await asAdmin.GetJsonAsync("/api/admin/payments");
        var row = queue.GetProperty("items").EnumerateArray().Single(r => r.GetProperty("paymentId").GetGuid() == firstPaymentId);
        Assert.False(row.GetProperty("mismatch").GetBoolean());
        var shot = await asAdmin.GetAsync($"/api/admin/payments/{firstPaymentId}/screenshots/2");
        Assert.Equal(HttpStatusCode.OK, shot.StatusCode);
        Assert.Equal("image/png", shot.Content.Headers.ContentType?.MediaType);
        Assert.Equal(HttpStatusCode.NotFound, (await asAdmin.GetAsync($"/api/admin/payments/{firstPaymentId}/screenshots/3")).StatusCode);

        var (rejectStatus, _) = await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId = firstPaymentId, action = "reject", reason = "الإيصال غير واضح" });
        Assert.Equal(HttpStatusCode.OK, rejectStatus);
        var (_, afterReject) = await asDoctor.GetJsonAsync($"/api/billing/invoices/{invoiceId}");
        Assert.Equal(InvoiceStatuses.Rejected, afterReject.Str("status"));
        Assert.Equal("الإيصال غير واضح", afterReject.GetProperty("payments")[0].Str("rejectionReason"));
        Assert.True(afterReject.GetProperty("canPay").GetBoolean());
        Assert.Contains(
            await TestData.WithDbAsync(Factory, db => db.Notifications.Where(n => n.RecipientUserId == doctor.Id).ToListAsync()),
            n => n.Type == BillingNotifications.PaymentRejected && n.BodyAr.Contains("الإيصال غير واضح"));

        // Reviewing the same payment again is refused.
        var (again, againBody) = await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId = firstPaymentId, action = "approve" });
        Assert.Equal(HttpStatusCode.Conflict, again);
        Assert.Equal(ErrorCodes.PaymentAlreadyReviewed, againBody.Code());

        var second = await SubmitAsync(asDoctor, invoiceId, 15000);
        var secondId = (await Http.BodyAsync(second)).GetProperty("paymentId").GetGuid();
        var (approveStatus, approved) = await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId = secondId, action = "approve" });
        Assert.Equal(HttpStatusCode.OK, approveStatus);
        Assert.Equal(InvoiceStatuses.Paid, approved.Str("status"));

        var paid = await TestData.WithDbAsync(Factory, db => db.Invoices.Include(i => i.InvoiceStatusHistories).SingleAsync(i => i.Id == invoiceId));
        Assert.Equal(admin.Id, paid.ClosedBy);
        Assert.Equal(PaidMethods.InstaPay, paid.PaidMethod);
        Assert.NotNull(paid.PaidAt);
        Assert.Equal(
            [InvoiceStatuses.Unpaid, InvoiceStatuses.PendingReview, InvoiceStatuses.Rejected, InvoiceStatuses.PendingReview, InvoiceStatuses.Paid],
            paid.InvoiceStatusHistories.OrderBy(h => h.ChangedAt).ThenBy(h => h.Status == InvoiceStatuses.Paid ? 1 : 0).Select(h => h.Status).ToArray());
        Assert.Contains(
            await TestData.WithDbAsync(Factory, db => db.Notifications.Where(n => n.RecipientUserId == doctor.Id).ToListAsync()),
            n => n.Type == BillingNotifications.PaymentApproved);
        var audits = await TestData.WithDbAsync(Factory, db => db.AuditLogs.Where(a => a.DoctorId == doctor.Id).Select(a => a.Action).ToListAsync());
        Assert.Contains(AuditActions.PaymentSubmitted, audits);
        Assert.Contains(AuditActions.PaymentRejected, audits);
        Assert.Contains(AuditActions.PaymentApproved, audits);
    }

    [Fact]
    public async Task A_payment_needs_one_to_three_image_screenshots_and_a_sensible_amount_and_date()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var url = $"/api/billing/invoices/{invoiceId}/submitPayment";

        using (var none = PaymentForm(15000, screenshots: 0))
        {
            var response = await asDoctor.PostAsync(url, none);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal(ErrorCodes.Required, (await Http.BodyAsync(response)).FieldCode("screenshots"));
        }

        using (var four = PaymentForm(15000, screenshots: 4))
        {
            var response = await asDoctor.PostAsync(url, four);
            Assert.Equal(ErrorCodes.TooManyScreenshots, (await Http.BodyAsync(response)).FieldCode("screenshots"));
        }

        using (var future = PaymentForm(15000, CairoTime.Today(TimeProvider.System).AddDays(1)))
        {
            var response = await asDoctor.PostAsync(url, future);
            Assert.Equal(ErrorCodes.OutOfRange, (await Http.BodyAsync(response)).FieldCode("transferDate"));
        }

        using (var zero = PaymentForm(0))
        {
            Assert.Equal(HttpStatusCode.BadRequest, (await asDoctor.PostAsync(url, zero)).StatusCode);
        }

        using (var notAnImage = PaymentForm(15000, screenshots: 0))
        {
            var text = new ByteArrayContent("not an image"u8.ToArray());
            text.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            notAnImage.Add(text, "screenshots", "fake.png");
            var response = await asDoctor.PostAsync(url, notAnImage);
            Assert.Equal(ErrorCodes.FileTypeNotAllowed, (await Http.BodyAsync(response)).FieldCode("screenshots"));
        }

        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.Payments.CountAsync(p => p.InvoiceId == invoiceId)));
        Assert.Equal(InvoiceStatuses.Unpaid, await TestData.WithDbAsync(Factory, db => db.Invoices.Where(i => i.Id == invoiceId).Select(i => i.Status).SingleAsync()));
    }

    [Fact]
    public async Task The_review_screen_flags_an_amount_that_differs_from_the_invoice()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var paymentId = (await Http.BodyAsync(await SubmitAsync(asDoctor, invoiceId, 10000))).GetProperty("paymentId").GetGuid();

        var (_, review) = await asAdmin.GetJsonAsync($"/api/admin/payments/{paymentId}");
        Assert.True(review.GetProperty("mismatch").GetBoolean());
        Assert.Equal(10000, review.GetProperty("payment").GetProperty("amountPiasters").GetInt32());
        Assert.Equal(15000, review.GetProperty("invoice").GetProperty("totalDuePiasters").GetInt32());
        Assert.Empty(review.GetProperty("earlierAttempts").EnumerateArray());
        var (rejectStatus, rejected) = await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId, action = "reject" });
        Assert.Equal(HttpStatusCode.BadRequest, rejectStatus);   // a rejection needs its reason
        Assert.Equal(ErrorCodes.ReasonRequired, rejected.FieldCode("reason"));
    }

    // ---- AC-8, AC-9 --------------------------------------------------------------------------------------------

    [Fact]
    public async Task An_unpaid_invoice_suspends_the_doctor_the_morning_after_the_due_date_and_paying_reactivates_them()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.OfficeManager);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        // 7 November, 00:10: not due yet. 8 November, 00:10: overdue and suspended (the worked example, 6.5).
        await using (var scope = Factory.CreateScope())
        {
            Assert.Equal(0, await TestData.BillingAt(scope, TestData.DailyCheckTime(new DateOnly(2026, 11, 7))).DailyCheckAsync(CancellationToken.None));
        }

        Assert.Equal(DoctorStatuses.Active, await StatusAsync(doctor.Id));
        await using (var scope = Factory.CreateScope())
        {
            Assert.True(await TestData.BillingAt(scope, TestData.DailyCheckTime(new DateOnly(2026, 11, 8))).DailyCheckAsync(CancellationToken.None) >= 1);
        }

        Assert.Equal(DoctorStatuses.Suspended, await StatusAsync(doctor.Id));
        var doctorRow = await TestData.WithDbAsync(Factory, db => db.Doctors.SingleAsync(d => d.UserId == doctor.Id));
        Assert.Equal("billing:2026-10", doctorRow.StatusReason);
        Assert.Equal(InvoiceStatuses.Overdue, await InvoiceStatusAsync(invoiceId));

        // AC-8: writes are refused for the doctor and the assistant; reading and paying still work.
        foreach (var client in new[] { asDoctor, asAssistant })
        {
            var (create, createBody) = await client.PostAsync("/api/patients/createPatient", new { fullName = "منى حسن", phone = TestData.Local(TestData.Mobile()), gender = "female", ageYears = 30 });
            Assert.Equal(HttpStatusCode.Forbidden, create);
            Assert.Equal(ErrorCodes.DoctorSuspended, createBody.Code());
            Assert.Equal(HttpStatusCode.OK, (await client.GetJsonAsync("/api/billing/invoices")).Status);
            Assert.Equal(HttpStatusCode.OK, (await client.GetJsonAsync("/api/patients/register")).Status);
        }

        var (_, list) = await asDoctor.GetJsonAsync("/api/billing/invoices");
        Assert.Equal("2026-10", list.GetProperty("suspension").Str("monthKey"));
        Assert.Equal(InvoiceStatuses.Overdue, list.GetProperty("attention").Str("status"));

        // The doctor and the assistant were told; the assistant's text has no billing reason (BR-G8).
        var notices = await TestData.WithDbAsync(Factory, db => db.Notifications
            .Where(n => n.Type == BillingNotifications.BillingSuspended && (n.RecipientUserId == doctor.Id || n.RecipientUserId == assistant.Id))
            .ToListAsync());
        Assert.Equal(2, notices.Count);
        Assert.DoesNotContain("فاتورة", notices.Single(n => n.RecipientUserId == assistant.Id).BodyAr);

        // Paying and an approval bring the doctor back at once.
        var paymentId = (await Http.BodyAsync(await SubmitAsync(asDoctor, invoiceId, 15000))).GetProperty("paymentId").GetGuid();
        Assert.Equal(DoctorStatuses.Suspended, await StatusAsync(doctor.Id));   // still suspended while it is reviewed
        await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId, action = "approve" });

        Assert.Equal(DoctorStatuses.Active, await StatusAsync(doctor.Id));
        Assert.Equal(HttpStatusCode.Created, (await asDoctor.PostAsync("/api/patients/createPatient", new { fullName = "منى حسن", phone = TestData.Local(TestData.Mobile()), gender = "female", ageYears = 30 })).Status);
        Assert.Contains(
            await TestData.WithDbAsync(Factory, db => db.Notifications.Where(n => n.RecipientUserId == doctor.Id).ToListAsync()),
            n => n.Type == BillingNotifications.BillingReactivated);
    }

    [Fact]
    public async Task A_payment_under_review_protects_the_doctor_and_a_rejection_after_the_due_date_suspends_at_once()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        // AC-9: submitted on 7 November, still pending on 8 November: not suspended.
        var paymentId = (await Http.BodyAsync(await SubmitAsync(asDoctor, invoiceId, 15000))).GetProperty("paymentId").GetGuid();
        await using (var scope = Factory.CreateScope())
        {
            await TestData.BillingAt(scope, TestData.DailyCheckTime(new DateOnly(2026, 11, 8))).DailyCheckAsync(CancellationToken.None);
        }

        Assert.Equal(DoctorStatuses.Active, await StatusAsync(doctor.Id));
        Assert.Equal(InvoiceStatuses.PendingReview, await InvoiceStatusAsync(invoiceId));

        // BR-G2: rejected after the due date (today is later than 7 November 2026): overdue and suspended straight away.
        var (status, body) = await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId, action = "reject", reason = "المبلغ غير مطابق" });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(InvoiceStatuses.Overdue, body.Str("status"));
        Assert.Equal(DoctorStatuses.Suspended, await StatusAsync(doctor.Id));
    }

    [Fact]
    public async Task A_suspension_an_admin_made_by_hand_is_not_lifted_by_paying()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        await asAdmin.PostAsync("/api/admin/setDoctorStatus", new { doctorId = doctor.Id, status = "suspended", reason = "شكوى من مريض" });

        var paymentId = (await Http.BodyAsync(await SubmitAsync(asDoctor, invoiceId, 15000))).GetProperty("paymentId").GetGuid();
        await asAdmin.PostAsync("/api/admin/reviewPayment", new { paymentId, action = "approve" });

        Assert.Equal(InvoiceStatuses.Paid, await InvoiceStatusAsync(invoiceId));
        Assert.Equal(DoctorStatuses.Suspended, await StatusAsync(doctor.Id));
    }

    [Fact]
    public async Task The_daily_check_reminds_two_days_before_and_on_the_due_date_once()
    {
        var (doctor, _) = await DoctorWithOctoberInvoiceAsync();

        foreach (var day in new[] { new DateOnly(2026, 11, 5), new DateOnly(2026, 11, 5), new DateOnly(2026, 11, 7), new DateOnly(2026, 11, 7) })
        {
            await using var scope = Factory.CreateScope();
            await TestData.BillingAt(scope, TestData.DailyCheckTime(day)).DailyCheckAsync(CancellationToken.None);
        }

        var types = await TestData.WithDbAsync(Factory, db => db.Notifications.Where(n => n.RecipientUserId == doctor.Id).Select(n => n.Type).ToListAsync());
        Assert.Equal(1, types.Count(t => t == BillingNotifications.InvoiceDueSoon));
        Assert.Equal(1, types.Count(t => t == BillingNotifications.InvoiceDueToday));
    }

    // ---- BR-PAY4 -----------------------------------------------------------------------------------------------

    [Fact]
    public async Task Admin_actions_need_a_reason_follow_the_status_rules_and_are_audited()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        // A reason is required for each action.
        Assert.Equal(ErrorCodes.ReasonRequired, (await asAdmin.PostAsync("/api/admin/waiveInvoice", new { invoiceId })).Body.FieldCode("reason"));
        Assert.Equal(ErrorCodes.ReasonRequired, (await asAdmin.PostAsync("/api/admin/adjustInvoice", new { invoiceId, amountPiasters = -500 })).Body.FieldCode("reason"));

        // Adjust: -5.00 EGP, then a +2.00 one; the total follows. Never to zero or below.
        var (_, adjusted) = await asAdmin.PostAsync("/api/admin/adjustInvoice", new { invoiceId, amountPiasters = -500, reason = "خصم تعويضي" });
        Assert.Equal(14500, adjusted.GetProperty("totalDuePiasters").GetInt32());
        await asAdmin.PostAsync("/api/admin/adjustInvoice", new { invoiceId, amountPiasters = 200, reason = "رسوم إضافية" });
        var (tooMuch, tooMuchBody) = await asAdmin.PostAsync("/api/admin/adjustInvoice", new { invoiceId, amountPiasters = -14700, reason = "خصم كامل" });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, tooMuch);
        Assert.Equal(ErrorCodes.AdjustmentInvalid, tooMuchBody.Code());
        var invoice = await TestData.WithDbAsync(Factory, db => db.Invoices.Include(i => i.InvoiceAdjustments).SingleAsync(i => i.Id == invoiceId));
        Assert.Equal(14700, invoice.TotalDuePiasters);
        Assert.Equal(-300, invoice.AdjustmentsPiasters);
        Assert.Equal(2, invoice.InvoiceAdjustments.Count);

        // Extend: later than the current due date only; extending past today brings an overdue invoice back to unpaid.
        var (earlier, earlierBody) = await asAdmin.PostAsync("/api/admin/extendInvoiceDueDate", new { invoiceId, newDueDate = "2026-11-01", reason = "اتفاق مع الطبيب" });
        Assert.Equal(HttpStatusCode.BadRequest, earlier);
        Assert.Equal(ErrorCodes.DueDateInvalid, earlierBody.FieldCode("newDueDate"));
        var later = CairoTime.Today(TimeProvider.System).AddDays(10);
        var (extended, extendedBody) = await asAdmin.PostAsync("/api/admin/extendInvoiceDueDate", new { invoiceId, newDueDate = later.ToString("yyyy-MM-dd"), reason = "اتفاق مع الطبيب" });
        Assert.Equal(HttpStatusCode.OK, extended);
        Assert.Equal(later.ToString("yyyy-MM-dd"), extendedBody.Str("dueDate"));

        // Mark paid, with a method and a note; then nothing else is allowed on a paid invoice.
        Assert.Equal(HttpStatusCode.BadRequest, (await asAdmin.PostAsync("/api/admin/markInvoicePaid", new { invoiceId, method = "bitcoin", note = "نقداً" })).Status);
        var (paid, paidBody) = await asAdmin.PostAsync("/api/admin/markInvoicePaid", new { invoiceId, method = "cash", note = "استلمنا نقداً في المكتب" });
        Assert.Equal(HttpStatusCode.OK, paid);
        Assert.Equal(InvoiceStatuses.Paid, paidBody.Str("status"));
        var (waive, waiveBody) = await asAdmin.PostAsync("/api/admin/waiveInvoice", new { invoiceId, reason = "بعد الدفع" });
        Assert.Equal(HttpStatusCode.Conflict, waive);
        Assert.Equal(ErrorCodes.InvoiceStatusInvalid, waiveBody.Code());
        Assert.Equal("cash", await TestData.WithDbAsync(Factory, db => db.Invoices.Where(i => i.Id == invoiceId).Select(i => i.PaidMethod).SingleAsync()));

        var audits = await TestData.WithDbAsync(Factory, db => db.AuditLogs.Where(a => a.DoctorId == doctor.Id && a.ActorUserId == admin.Id).Select(a => a.Action).ToListAsync());
        Assert.Equal(2, audits.Count(a => a == AuditActions.InvoiceAdjusted));
        Assert.Contains(AuditActions.InvoiceDueDateExtended, audits);
        Assert.Contains(AuditActions.InvoiceMarkedPaid, audits);
    }

    [Fact]
    public async Task Waiving_an_overdue_invoice_reactivates_the_doctor_and_the_timeline_shows_each_step()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        await using (var scope = Factory.CreateScope())
        {
            await TestData.BillingAt(scope, TestData.DailyCheckTime(new DateOnly(2026, 11, 8))).DailyCheckAsync(CancellationToken.None);
        }

        Assert.Equal(DoctorStatuses.Suspended, await StatusAsync(doctor.Id));
        var (status, _) = await asAdmin.PostAsync("/api/admin/waiveInvoice", new { invoiceId, reason = "ظروف خاصة" });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal(DoctorStatuses.Active, await StatusAsync(doctor.Id));
        var (_, detail) = await asAdmin.GetJsonAsync($"/api/admin/invoices/{invoiceId}");
        Assert.Equal(["unpaid", "overdue", "waived"], detail.GetProperty("timeline").EnumerateArray().Select(t => t.Str("status")).ToArray());
        Assert.Equal(doctor.Id, detail.GetProperty("doctor").GetProperty("id").GetGuid());
        var (_, doctorDetail) = await asDoctor.GetJsonAsync($"/api/billing/invoices/{invoiceId}");
        Assert.Equal(JsonValueKind.Null, doctorDetail.GetProperty("doctor").ValueKind);   // the doctor's own view has no doctor block
    }

    // ---- Lists ---------------------------------------------------------------------------------------------------

    [Fact]
    public async Task The_admin_invoice_list_filters_and_totals_the_whole_filtered_set()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync(exams: 3, consultations: 0);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        using var asAdmin = await Factory.SignedInClientAsync(admin);

        var (_, all) = await asAdmin.GetJsonAsync($"/api/admin/invoices?doctorId={doctor.Id}&month={TestData.October}&pageSize=1");
        Assert.Equal(1, all.GetProperty("page").GetProperty("totalCount").GetInt32());
        Assert.Equal(9000, all.GetProperty("totals").GetProperty("totalDuePiasters").GetInt32());
        Assert.Equal(3, all.GetProperty("totals").GetProperty("examCount").GetInt32());
        Assert.Equal(invoiceId, all.GetProperty("page").GetProperty("items")[0].GetProperty("id").GetGuid());

        var (_, none) = await asAdmin.GetJsonAsync($"/api/admin/invoices?doctorId={doctor.Id}&status=paid");
        Assert.Equal(0, none.GetProperty("totals").GetProperty("count").GetInt32());
        Assert.Equal(HttpStatusCode.BadRequest, (await asAdmin.GetJsonAsync("/api/admin/invoices?status=nonsense")).Status);
    }

    // ---- Who may do what -------------------------------------------------------------------------------------------

    [Fact]
    public async Task Billing_endpoints_check_the_role_the_assistant_permission_and_the_owner()
    {
        var (doctor, invoiceId) = await DoctorWithOctoberInvoiceAsync();
        var (otherDoctor, otherInvoice) = await DoctorWithOctoberInvoiceAsync();
        var viewer = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.BillingView]);
        var payer = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.BillingView, ClinicPermissions.BillingPay]);
        var blind = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.PatientsManage]);
        var admin = await TestData.CreateAdminAsync(Factory, AdminRoles.Admin);
        var (patientUser, _) = await TestData.CreatePatientAsync(Factory);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        using var asViewer = await Factory.SignedInClientAsync(viewer);
        using var asPayer = await Factory.SignedInClientAsync(payer);
        using var asBlind = await Factory.SignedInClientAsync(blind);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        using var asPatient = await Factory.SignedInClientAsync(patientUser);
        using var anonymous = Factory.Client();

        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetJsonAsync("/api/billing/invoices")).Status);
        // Patients and admins have no clinic billing; assistants need billingView, and billingPay to pay.
        Assert.Equal(HttpStatusCode.Forbidden, (await asPatient.GetJsonAsync("/api/billing/invoices")).Status);
        Assert.Equal(HttpStatusCode.Forbidden, (await asAdmin.GetJsonAsync("/api/billing/invoices")).Status);
        Assert.Equal(HttpStatusCode.Forbidden, (await asBlind.GetJsonAsync("/api/billing/invoices")).Status);
        Assert.Equal(HttpStatusCode.OK, (await asViewer.GetJsonAsync("/api/billing/invoices")).Status);
        Assert.Equal(HttpStatusCode.Forbidden, (await SubmitAsync(asViewer, invoiceId, 15000)).StatusCode);
        // Another doctor's invoice is not found, for reading and for paying.
        Assert.Equal(HttpStatusCode.NotFound, (await asDoctor.GetJsonAsync($"/api/billing/invoices/{otherInvoice}")).Status);
        Assert.Equal(HttpStatusCode.NotFound, (await SubmitAsync(asDoctor, otherInvoice, 15000)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await SubmitAsync(asPayer, invoiceId, 15000)).StatusCode);

        // The admin endpoints are for admins only, and the clinic's payments are not another doctor's to see.
        var adminRoutes = new[] { "/api/admin/payments", "/api/admin/invoices", $"/api/admin/invoices/{invoiceId}" };
        foreach (var route in adminRoutes)
        {
            Assert.Equal(HttpStatusCode.OK, (await asAdmin.GetJsonAsync(route)).Status);
            foreach (var client in new[] { asDoctor, asPayer, asPatient })
            {
                Assert.Equal(HttpStatusCode.Forbidden, (await client.GetJsonAsync(route)).Status);
            }
        }

        var paymentId = await TestData.WithDbAsync(Factory, db => db.Payments.Where(p => p.InvoiceId == invoiceId).Select(p => p.Id).SingleAsync());
        foreach (var client in new[] { asDoctor, asPayer, asPatient })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsync("/api/admin/reviewPayment", new { paymentId, action = "approve" })).Status);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsync("/api/admin/waiveInvoice", new { invoiceId, reason = "محاولة" })).Status);
        }

        using var otherClient = await Factory.SignedInClientAsync(otherDoctor);
        Assert.Equal(HttpStatusCode.NotFound, (await otherClient.GetAsync($"/api/billing/payments/{paymentId}/screenshots/1")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await asDoctor.GetAsync($"/api/billing/payments/{paymentId}/screenshots/1")).StatusCode);
    }

    // ---- stats reconcile -------------------------------------------------------------------------------------------

    [Fact]
    public async Task Stats_reconcile_corrects_a_day_whose_counters_drifted_and_logs_it()
    {
        var (doctor, patient) = await TestData.CreateDoctorWithPatientAsync(Factory);
        var day = new DateOnly(2026, 9, 14);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, day, "examination", 3000);
        await TestData.AddSessionAsync(Factory, doctor.Id, patient, day, "consultation", 1500);
        await TestData.WithDbAsync(Factory, async db =>
        {
            db.DailyStats.Add(new DailyStat { DoctorId = doctor.Id, DayKey = day, MonthKey = "2026-09", ExamCount = 5, ConsultationCount = 0, AmountPiasters = 99999 });
            await db.SaveChangesAsync();
        });

        await using (var scope = Factory.CreateScope())
        {
            Assert.True(await TestData.BillingAt(scope, TestData.DailyCheckTime(day.AddDays(1))).ReconcileStatsAsync(day, CancellationToken.None) >= 1);
        }

        var stat = await TestData.WithDbAsync(Factory, db => db.DailyStats.SingleAsync(d => d.DoctorId == doctor.Id && d.DayKey == day));
        Assert.Equal((1, 1, 4500), (stat.ExamCount, stat.ConsultationCount, stat.AmountPiasters));
        Assert.Contains(
            await TestData.WithDbAsync(Factory, db => db.AuditLogs.Where(a => a.DoctorId == doctor.Id).Select(a => a.Action).ToListAsync()),
            a => a == AuditActions.StatsReconciled);
        await using (var scope = Factory.CreateScope())
        {
            await TestData.BillingAt(scope, TestData.DailyCheckTime(day.AddDays(1))).ReconcileStatsAsync(day, CancellationToken.None);
        }

        Assert.Equal(1, await TestData.WithDbAsync(Factory, db => db.AuditLogs.CountAsync(a => a.DoctorId == doctor.Id && a.Action == AuditActions.StatsReconciled)));
    }

    // ---- helpers ---------------------------------------------------------------------------------------------------

    private Task<string> StatusAsync(Guid doctorId) =>
        TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.Status).SingleAsync());

    private Task<string> InvoiceStatusAsync(Guid invoiceId) =>
        TestData.WithDbAsync(Factory, db => db.Invoices.Where(i => i.Id == invoiceId).Select(i => i.Status).SingleAsync());
}
