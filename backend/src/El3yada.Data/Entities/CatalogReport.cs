using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class CatalogReport
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public string Type { get; set; } = null!;

    public string Text { get; set; } = null!;

    public string? ItemRef { get; set; }

    public string Status { get; set; } = "open";

    public Guid? HandledBy { get; set; }

    public DateTime? HandledAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual User? HandledByNavigation { get; set; }
}
