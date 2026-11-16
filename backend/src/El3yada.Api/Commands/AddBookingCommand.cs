using System.Globalization;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Commands;

/// <summary>
/// <c>dotnet run --project src/El3yada.Api -- add-booking --branch &lt;branchId&gt; --patient &lt;patientId&gt; [--date YYYY-MM-DD]</c>
/// <para>
/// Development only. Bookings get their endpoints in Phase 6, but branches already count them (D28's upcoming
/// bookings) and refuse to close or be archived while they have some (BR-BR9, <c>BRANCH_HAS_BOOKINGS</c>). This
/// inserts one open booking so the app's contract test can see those answers: confirmed, in the queue, made by the
/// doctor at the clinic, at 10:00 Cairo time on <c>--date</c> (default: tomorrow in Cairo), for one of the branch
/// doctor's patients. It prints the booking's ID. It refuses to run in any environment but Development.
/// </para>
/// </summary>
public static class AddBookingCommand
{
    public const string Name = "add-booking";

    private static readonly TimeOnly PeriodStart = new(10, 0);

    public static bool IsInvocation(string[] args) => args.Length > 0 && args[0] == Name;

    /// <summary>Runs the command with the app's services and returns the process exit code.</summary>
    public static async Task<int> RunAsync(IServiceProvider services, string[] args, TextWriter output)
    {
        await using var scope = services.CreateAsyncScope();
        var provider = scope.ServiceProvider;
        return await ExecuteAsync(
            provider.GetRequiredService<AppDbContext>(),
            provider.GetRequiredService<IHostEnvironment>(),
            provider.GetRequiredService<TimeProvider>(),
            args,
            output);
    }

    /// <summary>The command itself, called directly by tests. <paramref name="args"/> starts with "add-booking".</summary>
    public static async Task<int> ExecuteAsync(
        AppDbContext db, IHostEnvironment environment, TimeProvider time, string[] args, TextWriter output,
        CancellationToken cancellationToken = default)
    {
        if (!environment.IsDevelopment())
        {
            await output.WriteLineAsync(
                $"{Name} is for development only, and this is the {environment.EnvironmentName} environment. Nothing was changed.");
            return 1;
        }

        if (!TryParse(args, out var branchId, out var patientId, out var date, out var error))
        {
            await output.WriteLineAsync(error);
            await output.WriteLineAsync(
                $"Usage: dotnet run --project src/El3yada.Api -- {Name} --branch <branchId> --patient <patientId> [--date YYYY-MM-DD]");
            return 2;
        }

        var today = CairoTime.Today(time);
        var day = date ?? today.AddDays(1);
        if (day < today)
        {
            await output.WriteLineAsync($"The date {day:yyyy-MM-dd} is before today ({today:yyyy-MM-dd} in Cairo). Nothing was changed.");
            return 2;
        }

        var doctorId = await db.Branches.Where(b => b.Id == branchId).Select(b => (Guid?)b.DoctorId).SingleOrDefaultAsync(cancellationToken);
        if (doctorId is null)
        {
            await output.WriteLineAsync($"There is no branch {branchId}. Nothing was changed.");
            return 1;
        }

        if (!await db.DoctorPatients.AnyAsync(l => l.DoctorId == doctorId && l.PatientId == patientId, cancellationToken))
        {
            await output.WriteLineAsync($"The patient {patientId} is not one of this branch's doctor's patients. Nothing was changed.");
            return 1;
        }

        var queueNumber = 1 + (await db.Appointments
            .Where(a => a.BranchId == branchId && a.LocalDate == day && a.PeriodStartLocal == PeriodStart)
            .MaxAsync(a => a.QueueNumber, cancellationToken) ?? 0);
        var now = time.GetUtcNow().UtcDateTime;
        var booking = new Appointment
        {
            Id = Guid.NewGuid(),
            DoctorId = doctorId.Value,
            BranchId = branchId,
            PatientId = patientId,
            VisitType = "examination",
            Mode = "queue",
            LocalDate = day,
            PeriodStartLocal = PeriodStart,
            StartUtc = TimeZoneInfo.ConvertTimeToUtc(day.ToDateTime(PeriodStart, DateTimeKind.Unspecified), CairoTime.Zone),
            QueueNumber = queueNumber,
            Status = "confirmed",
            Source = "staff",
            BookedBy = doctorId.Value,
            BookedByRole = Roles.Doctor,
            CreatedAt = now,
            UpdatedAt = now,
        };
        db.Appointments.Add(booking);
        await db.SaveChangesAsync(cancellationToken);
        await output.WriteLineAsync(
            $"Added booking {booking.Id}: {day:yyyy-MM-dd} at 10:00 Cairo time, queue number {queueNumber}, confirmed.");
        return 0;
    }

    private static bool TryParse(string[] args, out Guid branchId, out Guid patientId, out DateOnly? date, out string error)
    {
        branchId = Guid.Empty;
        patientId = Guid.Empty;
        date = null;
        error = "";
        Guid? branch = null;
        Guid? patient = null;
        for (var i = 1; i < args.Length; i++)
        {
            var value = i + 1 < args.Length ? args[i + 1] : null;
            switch (args[i])
            {
                case "--branch" when Guid.TryParse(value, out var id):
                    branch = id;
                    i++;
                    break;
                case "--patient" when Guid.TryParse(value, out var id):
                    patient = id;
                    i++;
                    break;
                case "--date" when DateOnly.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day):
                    date = day;
                    i++;
                    break;
                default:
                    error = $"Unknown or incomplete argument: {args[i]}";
                    return false;
            }
        }

        if (branch is null || patient is null)
        {
            error = "Give the branch ID and the patient ID.";
            return false;
        }

        branchId = branch.Value;
        patientId = patient.Value;
        return true;
    }
}
