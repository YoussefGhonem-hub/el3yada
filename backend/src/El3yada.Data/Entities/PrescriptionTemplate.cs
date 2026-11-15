using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PrescriptionTemplate
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public string Kind { get; set; } = null!;

    public string Name { get; set; } = null!;

    public string ItemsJson { get; set; } = null!;

    public string? Advice { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;
}
