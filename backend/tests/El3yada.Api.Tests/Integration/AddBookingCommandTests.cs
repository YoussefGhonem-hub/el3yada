using System.Net;
using System.Text.RegularExpressions;
using El3yada.Api.Commands;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

namespace El3yada.Api.Tests.Integration;

/// <summary><c>dotnet run -- add-booking --branch … --patient …</c> (Development only), called through its handler.</summary>
[Collection(IntegrationCollection.Name)]
public sealed partial class AddBookingCommandTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [GeneratedRegex(@"Added booking ([0-9a-f-]{36})")]
    private static partial Regex PrintedId();

    /// <summary>Runs the command in <paramref name="environment"/>, or the test API's (Development).</summary>
    private async Task<(int ExitCode, string Output)> RunAsync(IHostEnvironment? environment, params string[] args)
    {
        await using var scope = Factory.CreateScope();
        var output = new StringWriter();
        var code = await AddBookingCommand.ExecuteAsync(
            scope.ServiceProvider.GetRequiredService<AppDbContext>(),
            environment ?? scope.ServiceProvider.GetRequiredService<IHostEnvironment>(),
            TimeProvider.System,
            ["add-booking", .. args],
            output);
        return (code, output.ToString());
    }

    private async Task<(TestUser Doctor, Guid BranchId, Guid PatientId)> ClinicWithPatientAsync()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branchId = await TestData.AddBranchAsync(Factory, doctor.Id);
        var (_, patientId) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, patientId);
        return (doctor, branchId, patientId);
    }

    [Fact]
    public async Task Adds_a_booking_for_tomorrow_that_the_branch_counts_and_that_stops_closing_and_archiving()
    {
        var (doctor, branchId, patientId) = await ClinicWithPatientAsync();

        var (code, output) = await RunAsync(null, "--branch", branchId.ToString(), "--patient", patientId.ToString());

        Assert.Equal(0, code);
        var bookingId = Guid.Parse(PrintedId().Match(output).Groups[1].Value);
        var booking = await TestData.WithDbAsync(Factory, db => db.Appointments.AsNoTracking().SingleAsync(a => a.Id == bookingId));
        Assert.Equal(doctor.Id, booking.DoctorId);
        Assert.Equal(branchId, booking.BranchId);
        Assert.Equal(patientId, booking.PatientId);
        Assert.Equal(TestData.CairoToday().AddDays(1), booking.LocalDate);
        Assert.Equal(new TimeOnly(10, 0), booking.PeriodStartLocal);
        Assert.Equal("confirmed", booking.Status);
        Assert.Equal("examination", booking.VisitType);
        Assert.Equal("queue", booking.Mode);
        Assert.Null(booking.QueueNumber);   // a place on the list; the number comes at check-in (BR-AP3)
        Assert.Equal(doctor.Id, booking.BookedBy);

        using var client = await Factory.SignedInClientAsync(doctor);
        var (_, list) = await client.GetJsonAsync("/api/branches");
        var cards = list.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(1, cards.Single(b => b.Str("id") == branchId.ToString()).GetProperty("upcomingBookings").GetInt32());
        Assert.Equal(0, cards.Single(b => b.Str("id") != branchId.ToString()).GetProperty("upcomingBookings").GetInt32());

        foreach (var body in new object[]
        {
            new { branchId, status = "archived" },
            new { branchId, status = "temporarilyClosed", closedMessage = "مغلق للتجديدات" },
        })
        {
            var (status, refusal) = await client.PostAsync("/api/branches/setBranchStatus", body);
            Assert.Equal(HttpStatusCode.Conflict, status);
            Assert.Equal(ErrorCodes.BranchHasBookings, refusal.Code());
            Assert.Equal(1, refusal.GetProperty("totalCount").GetInt32());
            var listed = refusal.GetProperty("bookings").EnumerateArray().Single();
            Assert.Equal(bookingId.ToString(), listed.Str("id"));
            Assert.Equal(patientId.ToString(), listed.Str("patientId"));
            Assert.Equal("منى حسن", listed.Str("name"));
            Assert.Equal("10:00", listed.Str("periodStartLocal"));
        }
    }

    [Fact]
    public async Task Takes_a_date_and_puts_each_booking_on_the_period_list_without_a_number()
    {
        var (_, branchId, patientId) = await ClinicWithPatientAsync();
        var day = TestData.CairoToday().AddDays(5).ToString("yyyy-MM-dd");

        var first = await RunAsync(null, "--branch", branchId.ToString(), "--patient", patientId.ToString(), "--date", day);
        var second = await RunAsync(null, "--date", day, "--patient", patientId.ToString(), "--branch", branchId.ToString());

        Assert.Equal(0, first.ExitCode);
        Assert.Equal(0, second.ExitCode);
        Assert.Contains("queue number at check-in", first.Output);
        var bookings = await TestData.WithDbAsync(Factory, db => db.Appointments.AsNoTracking()
            .Where(a => a.BranchId == branchId).ToListAsync());
        Assert.Equal(2, bookings.Count);
        Assert.All(bookings, a =>
        {
            Assert.Equal(DateOnly.Parse(day), a.LocalDate);
            Assert.Equal(new TimeOnly(10, 0), a.PeriodStartLocal);
            Assert.Null(a.QueueNumber);
        });
    }

    [Theory]
    [InlineData("Production")]
    [InlineData("Staging")]
    public async Task Refuses_to_run_outside_development(string environmentName)
    {
        var (_, branchId, patientId) = await ClinicWithPatientAsync();

        var (code, output) = await RunAsync(new StubEnvironment(environmentName), "--branch", branchId.ToString(), "--patient", patientId.ToString());

        Assert.Equal(1, code);
        Assert.Contains("development only", output);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.Appointments.AnyAsync(a => a.BranchId == branchId)));
    }

    [Fact]
    public async Task Refuses_an_unknown_branch_a_patient_of_another_clinic_and_a_past_date()
    {
        var (_, branchId, patientId) = await ClinicWithPatientAsync();
        var (_, stranger) = await TestData.CreatePatientAsync(Factory);
        var yesterday = TestData.CairoToday().AddDays(-1).ToString("yyyy-MM-dd");

        var unknownBranch = await RunAsync(null, "--branch", Guid.NewGuid().ToString(), "--patient", patientId.ToString());
        var notLinked = await RunAsync(null, "--branch", branchId.ToString(), "--patient", stranger.ToString());
        var past = await RunAsync(null, "--branch", branchId.ToString(), "--patient", patientId.ToString(), "--date", yesterday);

        Assert.Equal(1, unknownBranch.ExitCode);
        Assert.Contains("no branch", unknownBranch.Output);
        Assert.Equal(1, notLinked.ExitCode);
        Assert.Contains("not one of this branch's doctor's patients", notLinked.Output);
        Assert.Equal(2, past.ExitCode);
        Assert.Contains("before today", past.Output);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.Appointments.AnyAsync(a => a.BranchId == branchId)));
    }

    [Theory]
    [InlineData()]
    [InlineData("--branch", "not-a-guid", "--patient", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10")]
    [InlineData("--branch", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10")]
    [InlineData("--patient", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10")]
    [InlineData("--branch", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10", "--patient", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10", "--date", "tomorrow")]
    [InlineData("--branch", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10", "--patient", "6f1c1f4e-2c3b-4d0a-9a51-3d1f0d6b2a10", "--force")]
    public async Task Bad_arguments_print_the_usage(params string[] args)
    {
        var (code, output) = await RunAsync(null, args);

        Assert.Equal(2, code);
        Assert.Contains("Usage: dotnet run --project src/El3yada.Api -- add-booking --branch <branchId> --patient <patientId>", output);
    }

    private sealed class StubEnvironment(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;

        public string ApplicationName { get; set; } = "El3yada.Api";

        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
