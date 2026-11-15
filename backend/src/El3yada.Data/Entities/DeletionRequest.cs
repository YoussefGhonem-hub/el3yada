using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class DeletionRequest
{
    public Guid Id { get; set; }

    public Guid PatientId { get; set; }

    public string? Reason { get; set; }

    public string Status { get; set; } = "pending";

    public Guid? ReviewedBy { get; set; }

    public DateTime? ReviewedAt { get; set; }

    public string? ReviewNote { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Patient Patient { get; set; } = null!;

    public virtual User? ReviewedByNavigation { get; set; }
}
