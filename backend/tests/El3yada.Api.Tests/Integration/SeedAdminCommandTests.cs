using System.Net;
using System.Text.RegularExpressions;
using El3yada.Api.Auth;
using El3yada.Api.Commands;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary><c>dotnet run -- seed-admin &lt;email&gt;</c>, called through its handler.</summary>
[Collection(IntegrationCollection.Name)]
public sealed partial class SeedAdminCommandTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [GeneratedRegex(@"Temporary password \(shown once\): (\S+)")]
    private static partial Regex PrintedPassword();

    private async Task<(int ExitCode, string Output)> RunAsync(params string[] args)
    {
        await using var scope = Factory.CreateScope();
        var output = new StringWriter();
        var code = await SeedAdminCommand.ExecuteAsync(
            scope.ServiceProvider.GetRequiredService<AppDbContext>(),
            scope.ServiceProvider.GetRequiredService<Passwords>(),
            TimeProvider.System,
            ["seed-admin", .. args],
            output);
        return (code, output.ToString());
    }

    [Fact]
    public async Task Creates_a_super_admin_with_a_temporary_password_shown_once()
    {
        var email = TestData.Email("seed");

        var (code, output) = await RunAsync(email.ToUpperInvariant(), "--name", "Youssef Ghonem");

        Assert.Equal(0, code);
        var password = PrintedPassword().Match(output).Groups[1].Value;
        Assert.Equal(Passwords.AdminTemporaryLength, password.Length);
        var user = await TestData.WithDbAsync(Factory, db => db.Users.SingleAsync(u => u.Email == email));
        Assert.Equal("admin", user.Role);
        Assert.Equal(AdminRoles.SuperAdmin, user.AdminRole);
        Assert.True(user.MustChangePassword);
        Assert.Equal("Youssef Ghonem", user.DisplayName);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "adminSeeded" && a.TargetId == user.Id.ToString())));
        Assert.DoesNotContain(password, (await TestData.WithDbAsync(Factory, db => db.AuditLogs.Where(a => a.TargetId == user.Id.ToString()).Select(a => a.DetailsJson).ToListAsync())).Aggregate("", (a, b) => a + b));

        var login = await Factory.LoginAsync(email, password);
        Assert.True(login.GetProperty("mustChangePassword").GetBoolean());
        Assert.Equal("superAdmin", login.Str("adminRole"));
    }

    [Fact]
    public async Task Refuses_an_existing_email_unless_reset_is_asked_for_an_admin()
    {
        var email = TestData.Email("seed");
        var (_, firstOutput) = await RunAsync(email);
        var first = PrintedPassword().Match(firstOutput).Groups[1].Value;
        var session = await Factory.LoginAsync(email, first);

        var (again, againOutput) = await RunAsync(email);
        var (reset, resetOutput) = await RunAsync(email, "--reset");

        Assert.Equal(1, again);
        Assert.Contains("already exists", againOutput);
        Assert.DoesNotMatch(PrintedPassword(), againOutput);
        Assert.Equal(0, reset);
        var second = PrintedPassword().Match(resetOutput).Groups[1].Value;
        Assert.NotEqual(first, second);
        await Factory.LoginAsync(email, second);
        var (oldStatus, _) = await Factory.Client().PostAsync("/api/auth/refresh", new { refreshToken = session.Str("refreshToken") });
        Assert.Equal(HttpStatusCode.Unauthorized, oldStatus);
    }

    [Fact]
    public async Task Never_touches_an_account_that_is_not_an_admin()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);

        var (code, output) = await RunAsync(doctor.Identifier, "--reset");

        Assert.Equal(1, code);
        Assert.Contains("not an admin", output);
        await Factory.LoginAsync(doctor.Identifier, doctor.Password);
    }

    [Theory]
    [InlineData()]
    [InlineData("not-an-email")]
    [InlineData("a@b.co", "--name", "Single")]
    [InlineData("a@b.co", "--force")]
    public async Task Bad_arguments_print_the_usage(params string[] args)
    {
        var (code, output) = await RunAsync(args);

        Assert.Equal(2, code);
        Assert.Contains("Usage: dotnet run --project src/El3yada.Api -- seed-admin", output);
    }
}
