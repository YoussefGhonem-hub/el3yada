using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Commands;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Api.Development;
using El3yada.Api.Email;
using El3yada.Api.Features.Admin;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Features.Chat;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Realtime;
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
    // `dotnet run -- seed-admin <email>`, `seed-specialty-profiles <csv>` (and, in Development only, `add-booking …`)
    // run a one-time command instead of the web server.
    var isCommand = SeedAdminCommand.IsInvocation(args) || SeedSpecialtyProfilesCommand.IsInvocation(args) || AddBookingCommand.IsInvocation(args);
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
        // Delivers notifications after their rows are committed (spec 9.2).
        .AddInterceptors(services.GetRequiredService<NotificationDispatchInterceptor>())
        // EF logs a failed save with the SQL Server message, which holds the duplicate value of a unique index
        // (an email or a phone number). Endpoints catch those; anything uncaught is still logged by the
        // exception handler.
        // Savepoints: a failed save is never retried inside a transaction here; the transaction is rolled back.
        .ConfigureWarnings(warnings => warnings.Ignore(
            CoreEventId.SaveChangesFailed, RelationalEventId.CommandError, SqlServerEventId.SavepointsDisabledBecauseOfMARS)));

    builder.Services.AddSingleton<El3yada.Api.Storage.IFileStorage, LocalFileStorage>();
    builder.Services.AddSingleton<El3yada.Api.Infrastructure.Files.IFileStorage, El3yada.Api.Infrastructure.Files.FileStorageAdapter>();

    // JWT access tokens checked against the database on every request, refresh-token rotation, policies.
    builder.Services.AddAppAuth();
    builder.Services.AddAppRateLimiting();
    builder.Services.AddAppEmail();
    builder.Services.AddScoped<Auditor>();
    builder.Services.AddScoped<El3yada.Api.Notifications.NotificationWriter>();
    // Deletes medical files uploaded but never claimed by createRecord (Phase 3).
    builder.Services.AddSingleton<El3yada.Api.Records.PendingUploadCleanup>();
    builder.Services.AddHostedService(services => services.GetRequiredService<El3yada.Api.Records.PendingUploadCleanup>());

    // The caller and the clinic they act for, read from the token and the database (Phases 4–6 services).
    builder.Services.AddScoped<ICurrentUser, HttpCurrentUser>();
    builder.Services.AddScoped<StaffAccess>();
    builder.Services.AddSingleton<JwtTokenFactory>();
    builder.Services.AddScoped<SessionRevoker>();
    builder.Services.AddScoped<IAuditLogger, AuditLogger>();

    // Errors thrown as ApiException (Phases 4–6) leave as problem+json with a stable `code`.
    builder.Services.AddExceptionHandler<ApiExceptionHandler>();

    // Notifications (Phase 5): the single place that stores and delivers them (spec 9.2).
    builder.Services.AddScoped<INotificationWriter, El3yada.Api.Infrastructure.Notifications.NotificationWriter>();
    builder.Services.AddScoped<NotificationRecipients>();
    builder.Services.AddSingleton<NotificationQueue>();
    builder.Services.AddScoped<NotificationDispatchInterceptor>();
    builder.Services.AddSingleton<NotificationDispatcher>();
    builder.Services.AddHostedService(sp => sp.GetRequiredService<NotificationDispatcher>());

    // Real time: SignalR for chat, notifications and the live board; Firebase (FCM, Firestore) when configured.
    builder.Services.AddSignalR();
    builder.Services.AddSingleton<IRealtime, SignalRRealtime>();
    builder.Services.AddEl3yadaFirebase(builder.Configuration);

    // Phase 4: patient app, accounts support and deletion requests.
    builder.Services.AddScoped<PatientContext>();
    builder.Services.AddScoped<PatientPortalService>();
    builder.Services.AddScoped<PatientAccountService>();
    builder.Services.AddScoped<AdminSupportService>();

    // Phase 5: chat.
    builder.Services.AddScoped<ChatService>();

    // Phase 6: appointments, live board, schedule and jobs.
    builder.Services.AddScoped<ScheduleLoader>();
    builder.Services.AddScoped<BoardPublisher>();
    builder.Services.AddScoped<AppointmentService>();
    builder.Services.AddScoped<BoardActionsService>();
    builder.Services.AddScoped<ScheduleService>();
    builder.Services.AddScoped<AppointmentSearchService>();
    builder.Services.AddScoped<AppointmentJobs>();
    builder.Services.AddHostedService<AppointmentJobsHost>();

    // Phase 7: billing, payments and the analytics jobs (spec 9.3).
    builder.Services.AddScoped<El3yada.Api.Features.Appointments.DoctorClosureService>();
    builder.Services.AddScoped<El3yada.Api.Billing.BillingService>();
    builder.Services.AddScoped<El3yada.Api.Analytics.DailyMetricsBuilder>();
    builder.Services.AddScoped<El3yada.Api.Analytics.AnalyticsData>();
    builder.Services.AddScoped<El3yada.Api.Analytics.DashboardService>();
    builder.Services.AddScoped<El3yada.Api.Analytics.RevenueService>();
    builder.Services.AddSingleton<El3yada.Api.Billing.JobStatus>();
    builder.Services.AddScoped<El3yada.Api.Billing.BillingJobs>();
    builder.Services.AddHostedService<El3yada.Api.Billing.BillingJobsHost>();

    if (builder.Environment.IsDevelopment())
    {
        builder.Services.AddScoped<DemoDataSeeder>();
        builder.Services.AddScoped<DemoBillingSeeder>();
    }

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
        Environment.ExitCode = AddBookingCommand.IsInvocation(args)
            ? await AddBookingCommand.RunAsync(app.Services, args, Console.Out)
            : SeedSpecialtyProfilesCommand.IsInvocation(args)
                ? await SeedSpecialtyProfilesCommand.RunAsync(app.Services, args, Console.Out)
                : await SeedAdminCommand.RunAsync(app.Services, args, Console.Out);
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
    app.MapHub<AppHub>(AppHub.Path);
    app.MapDevEndpoints();

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

/// <summary>Entry point, public so the API tests can host it with WebApplicationFactory.</summary>
public partial class Program;
