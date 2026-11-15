using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class AuditLog
{
    public long Id { get; set; }

    public Guid? ActorUserId { get; set; }

    public string ActorRole { get; set; } = null!;

    public Guid? DoctorId { get; set; }

    public Guid? PatientId { get; set; }

    public string Action { get; set; } = null!;

    public string TargetType { get; set; } = null!;

    public string? TargetId { get; set; }

    public string? DetailsJson { get; set; }

    public DateTime At { get; set; }

    public virtual User? ActorUser { get; set; }

    public virtual Doctor? Doctor { get; set; }

    public virtual Patient? Patient { get; set; }
}
