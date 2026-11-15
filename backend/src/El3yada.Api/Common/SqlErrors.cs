using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Common;

public static class SqlErrors
{
    /// <summary>
    /// True when the save failed on a unique index (SQL Server errors 2601 and 2627), optionally a named one.
    /// Catch it and answer with a code; never log the SQL message, because it contains the duplicate value
    /// (an email or a phone number).
    /// </summary>
    public static bool IsUniqueViolation(this DbUpdateException exception, string? indexName = null) =>
        exception.InnerException is SqlException { Number: 2601 or 2627 } sql
        && (indexName is null || sql.Message.Contains(indexName, StringComparison.Ordinal));
}
