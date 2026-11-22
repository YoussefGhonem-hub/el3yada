using System.Data;
using El3yada.Api.Audit;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Sessions;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using AuditLogRow = El3yada.Data.Entities.AuditLog;

namespace El3yada.Api.Billing;

/// <summary>
/// The platform's billing rules (spec 6.5–6.7) used by the scheduled jobs and by the payment and admin endpoints:
/// month close, the daily overdue and suspension check, and the reactivation check. Every method is safe to run twice.
/// <para>
/// Totals are SQL aggregates over the non-deleted sessions' fee snapshots, never counters or count × current fee
/// (BR-B5). Dates and months are Cairo's.
/// </para>
/// </summary>
public sealed class BillingService(
    AppDbContext db,
    NotificationWriter notifications,
    Auditor auditor,
    AccountStateCache stateCache,
    TimeProvider time,
    ILogger<BillingService> logger)
{
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    private DateOnly Today => CairoTime.Today(time);

    // ---- Month close (BR-B5, AC-6) -------------------------------------------------------------------------

    /// <summary>
    /// <c>monthClose</c>: one invoice per doctor with sessions in <paramref name="monthKey"/>. A month whose fees
    /// are all 0 (the free trial, BR-T3) closes as <c>noCharge</c>. Doctors who already have the month's invoice are
    /// skipped, so running it again changes nothing. Returns the number of invoices created.
    /// <para>
    /// Fees of sessions saved after an earlier final invoice (a doctor who restored their account after paying it,
    /// BR-DEL10) are added to the new invoice as adjustment lines (<see cref="CarriesAsync"/>). A doctor with such fees
    /// and no session this month still gets the invoice. Each line names its month, so it is carried once.
    /// </para>
    /// </summary>
    public async Task<int> MonthlyCloseAsync(string monthKey, CancellationToken cancellationToken)
    {
        var first = CairoTime.ParseMonthKey(monthKey) ?? throw new ArgumentException("Not a month (yyyy-MM).", nameof(monthKey));
        var last = first.AddMonths(1).AddDays(-1);
        var grace = await db.AppSettings.AsNoTracking().Select(s => s.GracePeriodDays).SingleAsync(cancellationToken);

        var groups = await db.Sessions.AsNoTracking()
            .Where(s => s.MonthKey == monthKey && !s.Deleted
                && !db.Invoices.Any(i => i.DoctorId == s.DoctorId && i.MonthKey == monthKey))
            .GroupBy(s => new { s.DoctorId, s.BranchId, s.Type })
            .Select(g => new { g.Key.DoctorId, g.Key.BranchId, g.Key.Type, Count = g.Count(), Fees = g.Sum(s => s.FeePiasters) })
            .ToListAsync(cancellationToken);
        var carries = await CarriesAsync(null, monthKey, cancellationToken);
        var carryDoctors = carries.Keys.ToList();
        var invoiced = await db.Invoices.AsNoTracking()
            .Where(i => i.MonthKey == monthKey && carryDoctors.Contains(i.DoctorId))
            .Select(i => i.DoctorId)
            .ToListAsync(cancellationToken);

        var doctors = groups.Select(g => g.DoctorId).Concat(carryDoctors.Except(invoiced)).Distinct().ToList();
        var created = 0;
        foreach (var doctorId in doctors)
        {
            var plan = new PlannedInvoice(
                monthKey, first, last, last.AddDays(grace), IsFinal: false,
                groups.Where(g => g.DoctorId == doctorId).Select(g => (g.BranchId, g.Type, g.Count, g.Fees)).ToList(),
                carries.GetValueOrDefault(doctorId) ?? []);
            AddInvoice(doctorId, plan);
            try
            {
                await db.SaveChangesAsync(cancellationToken);
                created++;
            }
            catch (DbUpdateException ex) when (ex.IsUniqueViolation())
            {
                // Another run closed this doctor's month first (UQ_Invoices_Doctor_Month): nothing to do.
                db.ChangeTracker.Clear();
            }
        }

        return created;
    }

    /// <summary>
    /// Adds the invoice of <paramref name="plan"/> to the context, with its branch totals, its carried lines, its first
    /// status, the audit rows and the doctor's notification. Saves nothing.
    /// </summary>
    private Invoice AddInvoice(Guid doctorId, PlannedInvoice plan)
    {
        var now = Now;
        var groups = plan.Groups;
        int Count(string type) => groups.Where(g => g.Type == type).Sum(g => g.Count);
        int Fees(string type) => groups.Where(g => g.Type == type).Sum(g => g.Fees);

        var invoice = new Invoice
        {
            Id = Guid.NewGuid(),
            DoctorId = doctorId,
            MonthKey = plan.MonthKey,
            PeriodStart = plan.PeriodStart,
            PeriodEnd = plan.PeriodEnd,
            ExamCount = Count(SessionTypes.Examination),
            ConsultationCount = Count(SessionTypes.Consultation),
            ExamAmountPiasters = Fees(SessionTypes.Examination),
            ConsultationAmountPiasters = Fees(SessionTypes.Consultation),
            AdjustmentsPiasters = plan.CarriedPiasters,
            DueDate = plan.DueDate,
            IsFinal = plan.IsFinal,
            CreatedAt = now,
            UpdatedAt = now,
        };
        invoice.TotalDuePiasters = invoice.ExamAmountPiasters + invoice.ConsultationAmountPiasters + invoice.AdjustmentsPiasters;
        invoice.Status = invoice.TotalDuePiasters > 0 ? InvoiceStatuses.Unpaid : InvoiceStatuses.NoCharge;
        foreach (var branch in groups.GroupBy(g => g.BranchId))
        {
            invoice.InvoiceBranchBreakdowns.Add(new InvoiceBranchBreakdown
            {
                InvoiceId = invoice.Id,
                BranchId = branch.Key,
                ExamCount = branch.Where(g => g.Type == SessionTypes.Examination).Sum(g => g.Count),
                ConsultationCount = branch.Where(g => g.Type == SessionTypes.Consultation).Sum(g => g.Count),
                AmountPiasters = branch.Sum(g => g.Fees),
            });
        }

        foreach (var (month, amount) in plan.Carries)
        {
            invoice.InvoiceAdjustments.Add(new InvoiceAdjustment
            {
                Id = Guid.NewGuid(),
                InvoiceId = invoice.Id,
                AmountPiasters = amount,
                // The app shows its own text for a carried line (carriedMonthKey); this is for the audit and exports.
                Reason = $"Sessions saved after the final invoice of {month}",
                CarriedMonthKey = month,
                CreatedBy = null,
                CreatedAt = now,
            });
            auditor.Add(
                AuditActions.InvoiceFeesCarried, AuditTargets.Invoice, invoice.Id,
                new { fromMonthKey = month, toMonthKey = plan.MonthKey, amountPiasters = amount },
                doctorId: doctorId, actor: AuditActor.System);
        }

        db.Invoices.Add(invoice);
        AddHistory(invoice, invoice.Status, null, null);
        auditor.Add(
            AuditActions.InvoiceCreated, AuditTargets.Invoice, invoice.Id,
            new { monthKey = plan.MonthKey, status = invoice.Status, totalDuePiasters = invoice.TotalDuePiasters, isFinal = plan.IsFinal },
            doctorId: doctorId, actor: AuditActor.System);
        if (invoice.TotalDuePiasters > 0)
        {
            notifications.Add(
                doctorId, BillingNotifications.Created(plan.MonthKey, invoice.TotalDuePiasters, plan.DueDate),
                "/billing", new { invoiceId = invoice.Id });
        }

        return invoice;
    }

    // ---- Final invoices and carried fees (spec 6.17, BR-DEL8, BR-DEL10) -------------------------------------

    /// <summary>
    /// Fees of sessions saved after a final invoice and not billed yet, per doctor and month, for the months before
    /// <paramref name="beforeMonthKey"/>: the month's session fees now, minus what its final invoice billed and what
    /// earlier carried lines for that month billed. Only positive amounts. <paramref name="doctorId"/> null: every doctor.
    /// </summary>
    public async Task<Dictionary<Guid, List<(string MonthKey, int Amount)>>> CarriesAsync(
        Guid? doctorId, string beforeMonthKey, CancellationToken cancellationToken)
    {
        var rows = await db.Invoices.AsNoTracking()
            .Where(i => i.IsFinal && string.Compare(i.MonthKey, beforeMonthKey) < 0 && (doctorId == null || i.DoctorId == doctorId))
            .Select(i => new
            {
                i.DoctorId,
                i.MonthKey,
                Billed = i.ExamAmountPiasters + i.ConsultationAmountPiasters
                    + (db.InvoiceAdjustments
                        .Where(a => a.CarriedMonthKey == i.MonthKey && a.Invoice.DoctorId == i.DoctorId)
                        .Sum(a => (int?)a.AmountPiasters) ?? 0),
                Actual = db.Sessions
                    .Where(s => s.DoctorId == i.DoctorId && s.MonthKey == i.MonthKey && !s.Deleted)
                    .Sum(s => (int?)s.FeePiasters) ?? 0,
            })
            .ToListAsync(cancellationToken);
        return rows
            .Where(r => r.Actual > r.Billed)
            .GroupBy(r => r.DoctorId)
            .ToDictionary(
                g => g.Key,
                g => g.OrderBy(r => r.MonthKey, StringComparer.Ordinal).Select(r => (r.MonthKey, r.Actual - r.Billed)).ToList());
    }

    /// <summary>
    /// What deleting the doctor's account bills today (BR-DEL8): every past month with sessions and no invoice yet
    /// (closed as month close would), then the final invoice of the current month, closed early (<c>PeriodEnd</c> =
    /// today in Cairo) with the fees carried from earlier final invoices. When the current month already has an invoice
    /// (a final invoice the doctor paid before restoring), the fees since are billed in a final invoice under the next
    /// month's key, dated today. Invoices with nothing to bill are left out.
    /// </summary>
    public async Task<List<PlannedInvoice>> PlanFinalInvoicesAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        var today = Today;
        var current = CairoTime.MonthKey(today);
        var currentFirst = new DateOnly(today.Year, today.Month, 1);
        var next = CairoTime.MonthKey(currentFirst.AddMonths(1));
        var grace = await db.AppSettings.AsNoTracking().Select(s => s.GracePeriodDays).SingleAsync(cancellationToken);

        var groups = await db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == doctorId && !s.Deleted && string.Compare(s.MonthKey, current) <= 0
                && !db.Invoices.Any(i => i.DoctorId == doctorId && i.MonthKey == s.MonthKey))
            .GroupBy(s => new { s.MonthKey, s.BranchId, s.Type })
            .Select(g => new { g.Key.MonthKey, g.Key.BranchId, g.Key.Type, Count = g.Count(), Fees = g.Sum(s => s.FeePiasters) })
            .ToListAsync(cancellationToken);
        List<(Guid BranchId, string Type, int Count, int Fees)> Of(string month) =>
            groups.Where(g => g.MonthKey == month).Select(g => (g.BranchId, g.Type, g.Count, g.Fees)).ToList();

        var plans = new List<PlannedInvoice>();
        foreach (var month in groups.Select(g => g.MonthKey).Where(m => m != current).Distinct().Order(StringComparer.Ordinal))
        {
            var first = CairoTime.ParseMonthKey(month)!.Value;
            var last = first.AddMonths(1).AddDays(-1);
            plans.Add(new PlannedInvoice(month, first, last, last.AddDays(grace), IsFinal: false, Of(month), []));
        }

        var carries = (await CarriesAsync(doctorId, next, cancellationToken)).GetValueOrDefault(doctorId) ?? [];
        PlannedInvoice? final;
        if (!await db.Invoices.AnyAsync(i => i.DoctorId == doctorId && i.MonthKey == current, cancellationToken))
        {
            final = new PlannedInvoice(current, currentFirst, today, today.AddDays(grace), IsFinal: true, Of(current), carries);
        }
        else
        {
            final = await db.Invoices.AnyAsync(i => i.DoctorId == doctorId && i.MonthKey == next, cancellationToken)
                ? null
                : new PlannedInvoice(next, today, today, today.AddDays(grace), IsFinal: true, [], carries);
        }

        if (final is not null)
        {
            plans.Add(final);
        }

        return plans.Where(p => p.TotalPiasters > 0).ToList();
    }

    /// <summary>
    /// Issues the invoices of <see cref="PlanFinalInvoicesAsync"/> in the caller's transaction (saves nothing) and returns
    /// them. The final one has <see cref="Invoice.IsFinal"/>.
    /// </summary>
    public async Task<List<Invoice>> IssueFinalInvoicesAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        var issued = new List<Invoice>();
        foreach (var plan in await PlanFinalInvoicesAsync(doctorId, cancellationToken))
        {
            var invoice = AddInvoice(doctorId, plan);
            if (plan.IsFinal)
            {
                auditor.Add(
                    AuditActions.FinalInvoiceIssued, AuditTargets.Invoice, invoice.Id,
                    new { monthKey = plan.MonthKey, periodEnd = plan.PeriodEnd, totalDuePiasters = invoice.TotalDuePiasters },
                    doctorId: doctorId);
            }

            issued.Add(invoice);
        }

        return issued;
    }

    /// <summary>
    /// A doctor restored their account (BR-DEL10): their final invoice is removed while nothing was paid or sent for it
    /// (unpaid or overdue, no payment), so the month is invoiced at month close as usual. Otherwise it stays, and the
    /// fees of sessions saved after it are carried into the next invoice. Saves in the caller's transaction. Returns
    /// true when the invoice was removed.
    /// </summary>
    public async Task<bool> RemoveFinalInvoiceIfUnpaidAsync(Guid invoiceId, CancellationToken cancellationToken)
    {
        var invoice = await LockInvoiceAsync(invoiceId, cancellationToken);
        if (invoice is null || !invoice.IsFinal
            || invoice.Status is not (InvoiceStatuses.Unpaid or InvoiceStatuses.Overdue)
            || await db.Payments.AnyAsync(p => p.InvoiceId == invoiceId, cancellationToken))
        {
            return false;
        }

        var marker = invoiceId.ToString();
        await db.DeletionRequests.Where(r => r.FinalInvoiceId == invoiceId)
            .ExecuteUpdateAsync(set => set.SetProperty(r => r.FinalInvoiceId, (Guid?)null), cancellationToken);
        await db.InvoiceStatusHistories.Where(h => h.InvoiceId == invoiceId).ExecuteDeleteAsync(cancellationToken);
        await db.InvoiceBranchBreakdowns.Where(b => b.InvoiceId == invoiceId).ExecuteDeleteAsync(cancellationToken);
        await db.InvoiceAdjustments.Where(a => a.InvoiceId == invoiceId).ExecuteDeleteAsync(cancellationToken);
        await db.Notifications
            .Where(n => n.RecipientUserId == invoice.DoctorId && n.DataJson != null && n.DataJson.Contains(marker))
            .ExecuteDeleteAsync(cancellationToken);
        db.Invoices.Remove(invoice);
        auditor.Add(
            AuditActions.FinalInvoiceRemoved, AuditTargets.Invoice, invoiceId,
            new
            {
                monthKey = invoice.MonthKey, status = invoice.Status, totalDuePiasters = invoice.TotalDuePiasters,
                periodStart = invoice.PeriodStart, periodEnd = invoice.PeriodEnd,
            },
            doctorId: invoice.DoctorId);
        await db.SaveChangesAsync(cancellationToken);

        // An overdue final invoice suspended the doctor (BR-G1): without it they may be clear again.
        await ReactivateIfClearAsync(invoice.DoctorId, cancellationToken);
        return true;
    }

    // ---- Daily check (BR-G1, BR-G2, BR-G7) ---------------------------------------------------------------

    /// <summary>
    /// <c>dailyBillingCheck</c>: reminders 2 days before the due date and on it, then every <c>unpaid</c> or
    /// <c>rejected</c> invoice past its due date becomes <c>overdue</c> and its doctor is suspended. An invoice in
    /// <c>pendingReview</c> is never touched (BR-G2). Returns the number of invoices marked overdue.
    /// </summary>
    public async Task<int> DailyCheckAsync(CancellationToken cancellationToken)
    {
        var today = Today;
        await SendRemindersAsync(today, cancellationToken);

        var overdue = await db.Invoices
            .Where(i => (i.Status == InvoiceStatuses.Unpaid || i.Status == InvoiceStatuses.Rejected) && i.DueDate < today)
            .OrderBy(i => i.DueDate)
            .ToListAsync(cancellationToken);
        foreach (var invoice in overdue)
        {
            await MarkOverdueAsync(invoice, changedBy: null, cancellationToken);
        }

        await db.SaveChangesAsync(cancellationToken);
        foreach (var doctorId in overdue.Select(i => i.DoctorId).Distinct())
        {
            stateCache.Invalidate(doctorId);
        }

        // A doctor suspended for billing whose invoices are all settled (for example after an adjustment) is let back in.
        var billingSuspended = await db.Doctors
            .Where(d => d.Status == DoctorStatuses.Suspended && d.StatusReason != null && d.StatusReason.StartsWith(BillingSuspension.Prefix))
            .Select(d => d.UserId)
            .ToListAsync(cancellationToken);
        foreach (var doctorId in billingSuspended)
        {
            await ReactivateIfClearAsync(doctorId, cancellationToken);
        }

        return overdue.Count;
    }

    private async Task SendRemindersAsync(DateOnly today, CancellationToken cancellationToken)
    {
        var soon = await db.Invoices.AsNoTracking()
            .Where(i => (i.Status == InvoiceStatuses.Unpaid || i.Status == InvoiceStatuses.Rejected)
                && (i.DueDate == today.AddDays(2) || i.DueDate == today))
            .Select(i => new { i.Id, i.DoctorId, i.MonthKey, i.TotalDuePiasters, i.DueDate })
            .ToListAsync(cancellationToken);
        foreach (var invoice in soon)
        {
            var today2 = invoice.DueDate == today;
            var text = today2
                ? BillingNotifications.DueToday(invoice.MonthKey, invoice.TotalDuePiasters)
                : BillingNotifications.DueSoon(invoice.MonthKey, invoice.TotalDuePiasters, invoice.DueDate);
            var marker = invoice.Id.ToString();
            var already = await db.Notifications.AnyAsync(
                n => n.RecipientUserId == invoice.DoctorId && n.Type == text.Type && n.DataJson != null && n.DataJson.Contains(marker),
                cancellationToken);
            if (!already)
            {
                notifications.Add(invoice.DoctorId, text, "/billing", new { invoiceId = invoice.Id });
            }
        }

        await db.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Sets <paramref name="invoice"/> to <c>overdue</c> and suspends its doctor when active (BR-G1, and BR-G2 when an
    /// admin rejects a payment after the due date). Saves nothing: the caller does, in its transaction.
    /// </summary>
    public async Task MarkOverdueAsync(Invoice invoice, Guid? changedBy, CancellationToken cancellationToken)
    {
        var systemRun = changedBy is null;
        var now = Now;
        invoice.Status = InvoiceStatuses.Overdue;
        invoice.UpdatedAt = now;
        AddHistory(invoice, InvoiceStatuses.Overdue, null, changedBy);
        auditor.Add(
            AuditActions.InvoiceOverdue, AuditTargets.Invoice, invoice.Id, new { monthKey = invoice.MonthKey },
            doctorId: invoice.DoctorId, actor: systemRun ? AuditActor.System : null);

        var doctor = await db.Doctors.SingleAsync(d => d.UserId == invoice.DoctorId, cancellationToken);
        if (doctor.Status != DoctorStatuses.Active)
        {
            return;
        }

        doctor.Status = DoctorStatuses.Suspended;
        doctor.StatusReason = BillingSuspension.Reason(invoice.MonthKey);
        doctor.StatusChangedAt = now;
        doctor.UpdatedAt = now;
        notifications.Add(doctor.UserId, BillingNotifications.Suspended(invoice.MonthKey), "/billing", new { invoiceId = invoice.Id });
        foreach (var assistantId in await ActiveAssistantsAsync(doctor.UserId, cancellationToken))
        {
            notifications.Add(assistantId, BillingNotifications.SuspendedForAssistant(doctor.FullName), "/home", new { doctorId = doctor.UserId });
            stateCache.Invalidate(assistantId);
        }

        auditor.Add(
            AuditActions.DoctorSuspended, AuditTargets.Doctor, doctor.UserId,
            new { before = DoctorStatuses.Active, after = DoctorStatuses.Suspended, reason = "billing", monthKey = invoice.MonthKey },
            doctorId: doctor.UserId, actor: systemRun ? AuditActor.System : null);
    }

    // ---- Reactivation (BR-G3) ------------------------------------------------------------------------------

    /// <summary>
    /// A doctor suspended for billing becomes active when none of their invoices is overdue. Does nothing for a
    /// doctor an admin suspended by hand (BR-G4). Saves its own changes. Returns true when the doctor was reactivated.
    /// </summary>
    public async Task<bool> ReactivateIfClearAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        var doctor = await db.Doctors.SingleOrDefaultAsync(d => d.UserId == doctorId, cancellationToken);
        if (doctor is null || doctor.Status != DoctorStatuses.Suspended || !BillingSuspension.IsBilling(doctor.StatusReason))
        {
            return false;
        }

        if (await db.Invoices.AnyAsync(i => i.DoctorId == doctorId && i.Status == InvoiceStatuses.Overdue, cancellationToken))
        {
            return false;
        }

        var now = Now;
        doctor.Status = DoctorStatuses.Active;
        doctor.StatusReason = null;
        doctor.StatusChangedAt = now;
        doctor.UpdatedAt = now;
        notifications.Add(doctorId, BillingNotifications.Reactivated(), "/home", new { doctorId });
        var assistants = await ActiveAssistantsAsync(doctorId, cancellationToken);
        foreach (var assistantId in assistants)
        {
            notifications.Add(assistantId, BillingNotifications.ReactivatedForAssistant(doctor.FullName), "/home", new { doctorId });
        }

        auditor.Add(
            AuditActions.DoctorReactivated, AuditTargets.Doctor, doctorId,
            new { before = DoctorStatuses.Suspended, after = DoctorStatuses.Active, reason = "billing" },
            doctorId: doctorId);
        await db.SaveChangesAsync(cancellationToken);
        stateCache.Invalidate(doctorId);
        foreach (var assistantId in assistants)
        {
            stateCache.Invalidate(assistantId);
        }

        logger.LogInformation("Doctor {DoctorId} reactivated: no invoice is overdue", doctorId);
        return true;
    }

    // ---- Stats reconcile [S] -------------------------------------------------------------------------------

    /// <summary>
    /// <c>statsReconcile</c>: recalculates yesterday's <c>DailyStats</c> and its month's <c>MonthlyStats</c> from the
    /// sessions, fixes any difference and writes one audit row for it. Returns the number of corrected rows.
    /// </summary>
    public async Task<int> ReconcileStatsAsync(DateOnly day, CancellationToken cancellationToken)
    {
        var month = CairoTime.MonthKey(day);
        var corrected = 0;

        var actual = await db.Sessions.AsNoTracking()
            .Where(s => s.DayKey == day && !s.Deleted)
            .GroupBy(s => s.DoctorId)
            .Select(g => new
            {
                DoctorId = g.Key,
                Exams = g.Count(s => s.Type == SessionTypes.Examination),
                Consultations = g.Count(s => s.Type == SessionTypes.Consultation),
                Fees = g.Sum(s => s.FeePiasters),
            })
            .ToListAsync(cancellationToken);
        var stored = await db.DailyStats.Where(d => d.DayKey == day).ToListAsync(cancellationToken);

        foreach (var row in actual)
        {
            var stat = stored.FirstOrDefault(d => d.DoctorId == row.DoctorId);
            if (stat is null)
            {
                db.DailyStats.Add(new DailyStat
                {
                    DoctorId = row.DoctorId, DayKey = day, MonthKey = month,
                    ExamCount = row.Exams, ConsultationCount = row.Consultations, AmountPiasters = row.Fees,
                });
                Log(row.DoctorId, day, null, row.Exams, row.Consultations, row.Fees);
                corrected++;
            }
            else if (stat.ExamCount != row.Exams || stat.ConsultationCount != row.Consultations || stat.AmountPiasters != row.Fees)
            {
                Log(row.DoctorId, day, stat, row.Exams, row.Consultations, row.Fees);
                stat.ExamCount = row.Exams;
                stat.ConsultationCount = row.Consultations;
                stat.AmountPiasters = row.Fees;
                corrected++;
            }
        }

        foreach (var stat in stored.Where(d => actual.All(a => a.DoctorId != d.DoctorId)
            && (d.ExamCount != 0 || d.ConsultationCount != 0 || d.AmountPiasters != 0)))
        {
            Log(stat.DoctorId, day, stat, 0, 0, 0);
            stat.ExamCount = 0;
            stat.ConsultationCount = 0;
            stat.AmountPiasters = 0;
            corrected++;
        }

        await db.SaveChangesAsync(cancellationToken);

        // The month's counters are the sum of its days' sessions.
        var monthActual = await db.Sessions.AsNoTracking()
            .Where(s => s.MonthKey == month && !s.Deleted)
            .GroupBy(s => s.DoctorId)
            .Select(g => new
            {
                DoctorId = g.Key,
                Exams = g.Count(s => s.Type == SessionTypes.Examination),
                Consultations = g.Count(s => s.Type == SessionTypes.Consultation),
                Fees = g.Sum(s => s.FeePiasters),
            })
            .ToListAsync(cancellationToken);
        var monthStored = await db.MonthlyStats.Where(m => m.MonthKey == month).ToListAsync(cancellationToken);
        foreach (var row in monthActual)
        {
            var stat = monthStored.FirstOrDefault(m => m.DoctorId == row.DoctorId);
            if (stat is null)
            {
                db.MonthlyStats.Add(new MonthlyStat
                {
                    DoctorId = row.DoctorId, MonthKey = month,
                    ExamCount = row.Exams, ConsultationCount = row.Consultations, AmountPiasters = row.Fees,
                });
                corrected++;
            }
            else if (stat.ExamCount != row.Exams || stat.ConsultationCount != row.Consultations || stat.AmountPiasters != row.Fees)
            {
                stat.ExamCount = row.Exams;
                stat.ConsultationCount = row.Consultations;
                stat.AmountPiasters = row.Fees;
                corrected++;
            }
        }

        await db.SaveChangesAsync(cancellationToken);
        return corrected;

        void Log(Guid doctorId, DateOnly date, DailyStat? before, int exams, int consultations, int fees)
        {
            logger.LogWarning("DailyStats for {DoctorId} on {Day} differed from the sessions and were corrected", doctorId, date);
            auditor.Add(
                AuditActions.StatsReconciled, AuditTargets.Doctor, doctorId,
                new
                {
                    day = date,
                    before = before is null ? null : new { before.ExamCount, before.ConsultationCount, before.AmountPiasters },
                    after = new { examCount = exams, consultationCount = consultations, amountPiasters = fees },
                },
                doctorId: doctorId, actor: AuditActor.System);
        }
    }

    // ---- Helpers -------------------------------------------------------------------------------------------

    /// <summary>Adds a row to the invoice's status timeline (D19, AD10). <paramref name="changedBy"/> null is the system.</summary>
    public void AddHistory(Invoice invoice, string status, string? note, Guid? changedBy) =>
        db.InvoiceStatusHistories.Add(new InvoiceStatusHistory
        {
            Id = Guid.NewGuid(),
            InvoiceId = invoice.Id,
            Status = status,
            Note = note,
            ChangedBy = changedBy,
            ChangedAt = Now,
        });

    /// <summary>The doctor's assistants who can still sign in, for notices to the whole clinic.</summary>
    public Task<List<Guid>> ActiveAssistantsAsync(Guid doctorId, CancellationToken cancellationToken) =>
        db.Assistants.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.Status == "active" && a.User.Status == AccountStatuses.Active)
            .Select(a => a.UserId)
            .ToListAsync(cancellationToken);

    /// <summary>The assistants with <c>billingView</c>, who get billing notices too.</summary>
    public Task<List<Guid>> BillingAssistantsAsync(Guid doctorId, CancellationToken cancellationToken) =>
        db.Assistants.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.Status == "active" && a.BillingView && a.User.Status == AccountStatuses.Active)
            .Select(a => a.UserId)
            .ToListAsync(cancellationToken);

    /// <summary>Every active admin (AD17).</summary>
    public Task<List<Guid>> AdminIdsAsync(CancellationToken cancellationToken) =>
        db.Users.AsNoTracking()
            .Where(u => u.Role == Roles.Admin && u.Status == AccountStatuses.Active)
            .Select(u => u.Id)
            .ToListAsync(cancellationToken);

    /// <summary>Locks the invoice row for the transaction, so two admins or an admin and a doctor act one after the other.</summary>
    public async Task<Invoice?> LockInvoiceAsync(Guid invoiceId, CancellationToken cancellationToken)
    {
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT [Id] FROM [Invoices] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {invoiceId}", cancellationToken);
        return await db.Invoices.SingleOrDefaultAsync(i => i.Id == invoiceId, cancellationToken);
    }
}
