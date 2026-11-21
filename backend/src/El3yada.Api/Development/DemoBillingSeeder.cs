using El3yada.Api.Analytics;
using El3yada.Api.Billing;
using El3yada.Api.Common;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Development;

/// <summary>
/// Development only: on top of <see cref="DemoDataSeeder"/>, gives every demo account the password
/// <see cref="Password"/> (so the app's real login works), adds patients and about three months of sessions
/// for both doctors, closes the two finished months into invoices (one paid, one waiting, doctor B's with a
/// payment under review) and builds the daily metrics. Idempotent.
/// </summary>
public sealed class DemoBillingSeeder(
    AppDbContext db, DemoDataSeeder baseSeeder, BillingService billing, DailyMetricsBuilder metrics, IPasswordHasher<User> hasher, TimeProvider clock)
{
    public const string Password = "Dev@12345";

    private static readonly string[] Names =
    [
        "أحمد محمود", "فاطمة حسن", "محمود السيد", "نورا عادل", "عمر خالد", "ياسمين فتحي",
        "حسام الدين", "مريم عبد الله", "كريم سعيد", "هبة مصطفى", "طارق منصور", "دينا رأفت",
    ];

    public async Task<object> SeedAsync(CancellationToken ct)
    {
        var demo = await baseSeeder.SeedAsync(ct);
        var now = clock.GetUtcNow().UtcDateTime;
        var today = CairoTime.DayOf(now);

        // 1. Passwords: every demo account signs in with the same one.
        foreach (var user in await db.Users.ToListAsync(ct))
        {
            if (user.PasswordHash is null)
            {
                user.PasswordHash = hasher.HashPassword(user, Password);
                user.MustChangePassword = false;
                user.EmailVerifiedAt ??= user.Email is null ? null : now;
            }
        }
        await db.SaveChangesAsync(ct);

        var doctorA = await db.Doctors.SingleAsync(d => d.UserId == demo.DoctorAUserId, ct);
        var doctorB = await db.Doctors.SingleAsync(d => d.UserId == demo.DoctorBUserId, ct);
        if (await db.Sessions.CountAsync(s => s.DoctorId == doctorA.UserId, ct) > 20)
            return new { alreadySeeded = true, password = Password };

        var branchesA = await db.Branches.Where(b => b.DoctorId == doctorA.UserId && b.Status != "archived").OrderBy(b => b.CreatedAt).ToListAsync(ct);

        // 2. Patients, linked to doctor A (and some to B).
        var links = new List<DoctorPatient>();
        for (var i = 0; i < Names.Length; i++)
        {
            var phone = $"+2010{20000000 + i * 1111:D8}";
            var user = new User
            {
                Id = NewId.Next(), Role = "patient", DisplayName = Names[i], Phone = phone, SecurityStamp = Guid.NewGuid(),
                MustChangePassword = false, CreatedAt = now, UpdatedAt = now,
            };
            user.PasswordHash = hasher.HashPassword(user, Password);
            db.Users.Add(user);
            await db.SaveChangesAsync(ct);
            var patient = new Patient
            {
                Id = NewId.Next(), UserId = user.Id, FullName = Names[i], Phone = phone, Gender = i % 2 == 0 ? "male" : "female",
                DateOfBirth = new DateOnly(1970 + i * 3, 1 + i % 12, 10), CreatedByDoctorId = doctorA.UserId, CreatedAt = now, UpdatedAt = now,
            };
            db.Patients.Add(patient);
            await db.SaveChangesAsync(ct);
            foreach (var doctor in i % 3 == 0 ? new[] { doctorA, doctorB } : new[] { doctorA })
            {
                var link = new DoctorPatient
                {
                    Id = NewId.Next(), DoctorId = doctor.UserId, PatientId = patient.Id, FileNumber = doctor.NextFileNumber++,
                    PatientName = patient.FullName, PatientPhone = patient.Phone, SearchName = patient.FullName,
                    LinkedAt = now.AddDays(-100), LinkedBy = doctor.UserId, UpdatedAt = now,
                };
                db.DoctorPatients.Add(link);
                links.Add(link);
            }
            await db.SaveChangesAsync(ct);
        }
        var existingLinks = await db.DoctorPatients.Where(l => l.DoctorId == doctorA.UserId || l.DoctorId == doctorB.UserId).ToListAsync(ct);

        // 3. Sessions over the last ~95 days, a few per working day, with a weekday rhythm and a rising trend.
        var random = new Random(2026);
        var complaints = new[] { "صداع متكرر", "ألم في الظهر", "التهاب الحلق", "متابعة سكر", "ارتفاع ضغط", "كحة مستمرة" };
        var methods = new[] { "cash", "cash", "cash", "instapay", "card", "wallet" };
        var sessions = new List<Session>();
        for (var back = 95; back >= 0; back--)
        {
            var day = today.AddDays(-back);
            if (day.DayOfWeek == DayOfWeek.Friday) continue;
            foreach (var (doctor, branchIds) in new[] { (doctorA, branchesA.Select(b => b.Id).ToArray()), (doctorB, new[] { doctorB.DefaultBranchId!.Value }) })
            {
                var perDay = doctor == doctorA ? 2 + random.Next(0, 4) + (95 - back) / 30 : random.Next(0, 3);
                var doctorLinks = existingLinks.Where(l => l.DoctorId == doctor.UserId).ToList();
                for (var k = 0; k < perDay && doctorLinks.Count > 0; k++)
                {
                    var link = doctorLinks[random.Next(doctorLinks.Count)];
                    var consultation = random.NextDouble() < 0.3;
                    var type = consultation ? "consultation" : "examination";
                    var price = consultation ? 15000 : 30000;
                    var at = CairoTime.StartUtc(day).AddHours(11 + k * 1.2);
                    sessions.Add(new Session
                    {
                        Id = NewId.Next(), DoctorId = doctor.UserId, PatientId = link.PatientId, LinkId = link.Id,
                        BranchId = branchIds[random.Next(branchIds.Length)], Type = type,
                        FeePiasters = consultation ? 1500 : 3000, PatientFeePiasters = price, ListPricePiasters = price,
                        PaymentMethod = methods[random.Next(methods.Length)],
                        DayKey = day, MonthKey = CairoTime.MonthKey(day), CreatedBy = doctor.UserId, CreatedByRole = "doctor",
                        ChiefComplaint = complaints[random.Next(complaints.Length)], CreatedAt = at, UpdatedAt = at,
                    });
                }
            }
        }
        db.Sessions.AddRange(sessions);
        await db.SaveChangesAsync(ct);

        // 4. Close the two finished months. The older one is paid; the last one waits (B's has a payment to review).
        var months = new[] { 3, 2, 1 }.Select(m => CairoTime.MonthKey(new DateOnly(today.Year, today.Month, 1).AddMonths(-m))).ToArray();
        foreach (var month in months) await billing.MonthlyCloseAsync(month, ct);

        var invoices = await db.Invoices.ToListAsync(ct);
        foreach (var invoice in invoices.Where(i => i.MonthKey == months[0] || i.MonthKey == months[1]))
        {
            invoice.Status = InvoiceStatuses.Paid;
            invoice.PaidAt = now.AddDays(-20);
            invoice.PaidMethod = "instapay";
        }
        var waiting = invoices.FirstOrDefault(i => i.MonthKey == months[2] && i.DoctorId == doctorB.UserId && i.TotalDuePiasters > 0);
        if (waiting is not null)
        {
            waiting.Status = InvoiceStatuses.PendingReview;
            var payment = new Payment
            {
                Id = NewId.Next(), InvoiceId = waiting.Id, DoctorId = doctorB.UserId, AmountPiasters = waiting.TotalDuePiasters,
                TransferDate = today.AddDays(-1), Reference = "IP-884213", SenderName = "منى حسن", Status = "pendingReview",
                SubmittedBy = doctorB.UserId, SubmittedAt = now.AddHours(-3),
            };
            db.Payments.Add(payment);
            await db.SaveChangesAsync(ct);
            db.PaymentScreenshots.Add(new PaymentScreenshot { Id = NewId.Next(), PaymentId = payment.Id, Path = $"demo/payment-{payment.Id}.png", SortOrder = 1 });
        }
        await db.SaveChangesAsync(ct);

        // 5. Daily metrics for the whole range.
        for (var back = 95; back >= 0; back--) await metrics.BuildDayAsync(today.AddDays(-back), null, ct);

        return new
        {
            password = Password, sessions = sessions.Count, invoices = await db.Invoices.CountAsync(ct), closedMonths = months,
            logins = new[] { "admin@el3yada.dev", "doctor@el3yada.dev", "doctor.b@el3yada.dev", "01000000001 (assistant)", "01000000002 (patient)" },
        };
    }
}

