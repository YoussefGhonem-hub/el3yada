using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PrescriptionInvestigationItem
{
    public Guid Id { get; set; }

    public Guid PrescriptionId { get; set; }

    public int SortOrder { get; set; }

    public string Category { get; set; } = null!;

    public string Name { get; set; } = null!;

    public string? LoincCode { get; set; }

    public string? Notes { get; set; }

    public virtual Prescription Prescription { get; set; } = null!;
}
