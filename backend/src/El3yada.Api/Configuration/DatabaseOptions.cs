using System.ComponentModel.DataAnnotations;
using Microsoft.Data.SqlClient;

namespace El3yada.Api.Configuration;

/// <summary>
/// The SQL Server connection string (ConnectionStrings:Default). Development uses LocalDB from
/// appsettings.Development.json; production reads the ConnectionStrings__Default environment variable.
/// </summary>
public sealed class DatabaseOptions : IValidatableObject
{
    public const string SectionName = "ConnectionStrings";

    [Required(ErrorMessage = "ConnectionStrings:Default is missing. Production: set the ConnectionStrings__Default environment variable.")]
    public string Default { get; set; } = "";

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        string? error = null;
        try
        {
            _ = new SqlConnectionStringBuilder(Default);
        }
        catch (Exception ex) when (ex is ArgumentException or FormatException or KeyNotFoundException)
        {
            // The message never contains the connection string, which may hold a password.
            error = "ConnectionStrings:Default is not a valid SQL Server connection string.";
        }

        if (error is not null)
        {
            yield return new ValidationResult(error, [nameof(Default)]);
        }
    }
}
