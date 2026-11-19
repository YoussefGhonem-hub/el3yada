using El3yada.Api.Development;
using El3yada.Api.Features.Admin;
using El3yada.Api.Features.Chat;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Realtime;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Files;
using El3yada.Api.Infrastructure.Json;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// SQL Server. Development uses LocalDB (appsettings.Development.json);
// production reads ConnectionStrings__Default from the environment.
builder.Services.AddDbContext<AppDbContext>((services, options) => options
    .UseSqlServer(builder.Configuration.GetConnectionString("Default"))
    // Delivers notifications after their rows are committed (spec 9.2).
    .AddInterceptors(services.GetRequiredService<NotificationDispatchInterceptor>()));

builder.Services.AddSingleton(TimeProvider.System);

// Errors: every failure is ProblemDetails with a `code` (PHASES "How we work").
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = ApiExceptionHandler.Customize);
builder.Services.AddExceptionHandler<ApiExceptionHandler>();

// Auth: JWT bearer, deny by default, account status read from the database on every request.
builder.Services.AddEl3yadaAuth(builder.Configuration);
builder.Services.AddScoped<SessionRevoker>();

// Shared services.
builder.Services.AddScoped<IAuditLogger, AuditLogger>();
builder.Services.AddScoped<INotificationWriter, NotificationWriter>();
builder.Services.AddScoped<NotificationRecipients>();
builder.Services.AddSingleton<NotificationQueue>();
builder.Services.AddScoped<NotificationDispatchInterceptor>();
builder.Services.AddSingleton<NotificationDispatcher>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<NotificationDispatcher>());

// Real time: SignalR for chat, notifications and the live board; Firebase (FCM, Firestore) when configured.
builder.Services.AddSignalR();
builder.Services.AddSingleton<IRealtime, SignalRRealtime>();
builder.Services.AddEl3yadaFirebase(builder.Configuration);
builder.Services.AddOptions<FileStorageOptions>()
    .Bind(builder.Configuration.GetSection(FileStorageOptions.Section))
    .ValidateDataAnnotations();
builder.Services.AddSingleton<IFileStorage, LocalFileStorage>();

// Validation (spec 11): FluentValidation validators in this assembly, run by a global filter.
builder.Services.AddValidatorsFromAssemblyContaining<Program>(ServiceLifetime.Singleton);

// Phase 4: patient app, accounts support and deletion requests.
builder.Services.AddScoped<PatientContext>();
builder.Services.AddScoped<PatientPortalService>();
builder.Services.AddScoped<PatientAccountService>();
builder.Services.AddScoped<AdminSupportService>();

// Phase 5: chat.
builder.Services.AddScoped<ChatService>();

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddScoped<DemoDataSeeder>();
}

builder.Services.AddControllers(options => options.Filters.Add<FluentValidationFilter>())
    .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new UtcDateTimeConverter()));
// OpenAPI document at /openapi/v1.json in Development.
builder.Services.AddOpenApi();

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi().AllowAnonymous();
}

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<AppHub>(AppHub.Path);
app.MapDevEndpoints();

app.Run();

/// <summary>Entry point, public so the API tests can host it with WebApplicationFactory.</summary>
public partial class Program;
