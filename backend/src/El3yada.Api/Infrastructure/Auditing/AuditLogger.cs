using System.Text.Json;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Data;
using El3yada.Data.Entities;

namespace El3yada.Api.Infrastructure.Auditing;

/// <summary>
/// The single helper every endpoint uses to write <c>AuditLogs</c> (PHASES "How we work").
/// It only adds the row to the context, so the entry is saved in the same
/// <c>SaveChanges</c> (and transaction) as the change it describes.
/// </summary>
public interface IAuditLogger
{
    /// <param name="action">Dotted name, for example <c>deletionRequest.approved</c>.</param>
    /// <param name="targetType">The table or entity, for example <c>DeletionRequest</c>.</param>
    /// <param name="details">Small object serialized to JSON. Never put medical content here.</param>
    void Add(string action, string targetType, object? targetId, Guid? doctorId = null, Guid? patientId = null, object? details = null);
}

public sealed class AuditLogger(AppDbContext db, ICurrentUser user, TimeProvider clock) : IAuditLogger
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public void Add(string action, string targetType, object? targetId, Guid? doctorId = null, Guid? patientId = null, object? details = null)
    {
        db.AuditLogs.Add(new AuditLog
        {
            ActorUserId = user.IsAuthenticated ? user.UserId : null,
            ActorRole = user.IsAuthenticated ? user.Role : "system",
            DoctorId = doctorId,
            PatientId = patientId,
            Action = action,
            TargetType = targetType,
            TargetId = targetId?.ToString(),
            DetailsJson = details is null ? null : JsonSerializer.Serialize(details, Json),
            At = clock.GetUtcNow().UtcDateTime,
        });
    }
}
