using El3yada.Api.Configuration;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Serilog;

// Console logger for errors before the app is built; replaced by the configured logger below.
Log.Logger = new LoggerConfiguration().WriteTo.Console().CreateLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // Serilog: console and a daily file, set in the "Serilog" section of appsettings*.json.
    // Never log request bodies, phone numbers, tokens or medical text (spec section 12).
    builder.Services.AddSerilog((services, logger) => logger
        .ReadFrom.Configuration(builder.Configuration)
        .ReadFrom.Services(services));

    // ConnectionStrings, Jwt and Storage settings, checked at start-up. Secrets come from
    // user-secrets in Development and from environment variables in production (backend/README.md).
    builder.Services.AddAppOptions(builder.Configuration, builder.Environment);

    builder.Services.AddDbContext<AppDbContext>((services, options) =>
        options.UseSqlServer(services.GetRequiredService<IOptions<DatabaseOptions>>().Value.Default));

    builder.Services.AddSingleton<IFileStorage, LocalFileStorage>();

    // FluentValidation: every validator in this assembly runs on the matching action argument
    // before the action (ValidationFilter), and failures return a 400 ValidationProblem.
    // A field stops at its first failing rule, so it gets one error.
    ValidatorOptions.Global.DefaultRuleLevelCascadeMode = CascadeMode.Stop;
    builder.Services.AddValidatorsFromAssemblyContaining<Program>();
    builder.Services.AddControllers(options => options.Filters.Add<ValidationFilter>());
    builder.Services.AddProblemDetails();
    // OpenAPI document at /openapi/v1.json in Development.
    builder.Services.AddOpenApi();

    var app = builder.Build();

    // One line per request: method, path, status and time. No query string, headers or body.
    app.UseSerilogRequestLogging();
    // Errors become ProblemDetails responses without internal details.
    app.UseExceptionHandler();
    app.UseStatusCodePages();

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
    }

    app.UseHttpsRedirection();

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
