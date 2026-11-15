using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Commands;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Api.Email;
using El3yada.Api.Notifications;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;
using Serilog;

// Console logger for errors before the app is built; replaced by the configured logger below.
Log.Logger = new LoggerConfiguration().WriteTo.Console().CreateLogger();

try
{
    // `dotnet run -- seed-admin <email>` runs a one-time command instead of the web server.
    var isCommand = SeedAdminCommand.IsInvocation(args);
    var builder = WebApplication.CreateBuilder(isCommand ? [] : args);

    // Serilog: console and a daily file, set in the "Serilog" section of appsettings*.json.
    // Never log request bodies, phone numbers, emails, tokens or medical text (spec section 12).
    builder.Services.AddSerilog((services, logger) => logger
        .ReadFrom.Configuration(builder.Configuration)
        .ReadFrom.Services(services));

    // ConnectionStrings, Jwt, Auth, Email, RateLimits and Storage settings, checked at start-up. Secrets come
    // from user-secrets in Development and from environment variables in production (backend/README.md).
    builder.Services.AddAppOptions(builder.Configuration, builder.Environment);

    builder.Services.AddDbContext<AppDbContext>((services, options) => options
        .UseSqlServer(services.GetRequiredService<IOptions<DatabaseOptions>>().Value.Default)
        // EF logs a failed save with the SQL Server message, which holds the duplicate value of a unique index
        // (an email or a phone number). Endpoints catch those; anything uncaught is still logged by the
        // exception handler.
        // Savepoints: a failed save is never retried inside a transaction here; the transaction is rolled back.
        .ConfigureWarnings(warnings => warnings.Ignore(
            CoreEventId.SaveChangesFailed, RelationalEventId.CommandError, SqlServerEventId.SavepointsDisabledBecauseOfMARS)));

    builder.Services.AddSingleton<IFileStorage, LocalFileStorage>();

    // JWT access tokens checked against the database on every request, refresh-token rotation, policies.
    builder.Services.AddAppAuth();
    builder.Services.AddAppRateLimiting();
    builder.Services.AddAppEmail();
    builder.Services.AddScoped<Auditor>();
    builder.Services.AddScoped<NotificationWriter>();

    // FluentValidation: every validator in this assembly runs on the matching action argument
    // before the action (ValidationFilter), and failures return a 400 ValidationProblem.
    // A field stops at its first failing rule, so it gets one error.
    ValidatorOptions.Global.DefaultRuleLevelCascadeMode = CascadeMode.Stop;
    // DoctorRegistrationValidator takes a mode (new or resubmit) and is created by its controller.
    builder.Services.AddValidatorsFromAssemblyContaining<Program>(
        filter: scan => scan.ValidatorType != typeof(El3yada.Api.Doctors.DoctorRegistrationValidator));
    builder.Services
        .AddControllers(options =>
        {
            options.Filters.Add<ValidationFilter>();
            // An account with mustChangePassword may only call the endpoints marked for it (A9).
            options.Filters.Add<PasswordChangeGate>();
        })
        .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new UtcDateTimeConverter()))
        .ConfigureApiBehaviorOptions(options =>
            options.InvalidModelStateResponseFactory = ValidationProblems.FromModelState);
    // Every problem+json response carries a stable `code` (ErrorCodes.cs).
    builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
        context.ProblemDetails.Extensions.TryAdd("code", ApiProblems.CodeForStatus(context.ProblemDetails.Status)));
    // OpenAPI document at /openapi/v1.json in Development.
    builder.Services.AddOpenApi();

    var app = builder.Build();

    if (isCommand)
    {
        Environment.ExitCode = await SeedAdminCommand.RunAsync(app.Services, args, Console.Out);
        return;
    }

    // One line per request: method, path, status and time. No query string, headers or body.
    app.UseSerilogRequestLogging();
    // Errors become ProblemDetails responses without internal details.
    app.UseExceptionHandler();
    app.UseStatusCodePages();

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi().AllowAnonymous();
    }

    app.UseHttpsRedirection();

    app.UseRateLimiter();
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    // HostAbortedException is how `dotnet ef` stops the app after reading its services.
    Log.Fatal(ex, "The API stopped because of an error");
    Environment.ExitCode = 1;
}
finally
{
    Log.CloseAndFlush();
}
