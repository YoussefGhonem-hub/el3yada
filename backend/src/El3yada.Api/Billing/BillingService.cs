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

        var created = 0;
        foreach (var doctor in groups.GroupBy(g => g.DoctorId))
        {
            if (await CreateInvoiceAsync(doctor.Key, monthKey, first, last, last.AddDays(grace), doctor.Select(g => (g.BranchId, g.Type, g.Count, g.Fees)).ToList(), cancellationToken))
            {
                created++;
            }
        }

        return created;
    }

    private async Task<bool> CreateInvoiceAsync(
        Guid doctorId, string monthKey, DateOnly first, DateOnly last, DateOnly due,
        List<(Guid BranchId, string Type, int Count, int Fees)> groups, CancellationToken cancellationToken)
    {
        var now = Now;
        int Count(string type) => groups.Where(g => g.Type == type).Sum(g => g.Count);
        int Fees(string type) => groups.Where(g => g.Type == type).Sum(g => g.Fees);

        var invoice = new Invoice
        {
            Id = Guid.NewGuid(),
            DoctorId = doctorId,
            MonthKey = monthKey,
            PeriodStart = first,
            PeriodEnd = last,
            ExamCount = Count(SessionTypes.Examination),
            ConsultationCount = Count(SessionTypes.Consultation),
            ExamAmountPiasters = Fees(SessionTypes.Examination),
            ConsultationAmountPiasters = Fees(SessionTypes.Consultation),
            DueDate = due,
            CreatedAt = now,
            UpdatedAt = now,
        };
        invoice.TotalDuePiasters = invoice.ExamAmountPiasters + invoice.ConsultationAmountPiasters;
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

        db.Invoices.Add(invoice);
        AddHistory(invoice, invoice.Status, null, null);
        auditor.Add(
            AuditActions.InvoiceCreated, AuditTargets.Invoice, invoice.Id,
            new { monthKey, status = invoice.Status, totalDuePiasters = invoice.TotalDuePiasters },
            doctorId: doctorId, actor: AuditActor.System);
        if (invoice.TotalDuePiasters > 0)
        {
            notifications.Add(
                doctorId, BillingNotifications.Created(monthKey, invoice.TotalDuePiasters, due),
                "/billing", new { invoiceId = invoice.Id });
        }

        try
        {
            await db.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation())
        {
            // Another run closed this doctor's month first (UQ_Invoices_Doctor_Month): nothing to do.
            db.ChangeTracker.Clear();
            return false;
        }
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
