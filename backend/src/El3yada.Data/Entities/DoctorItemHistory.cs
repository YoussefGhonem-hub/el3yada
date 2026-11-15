using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class DoctorItemHistory
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public string Kind { get; set; } = null!;

    public string Name { get; set; } = null!;

    public string? CatalogId { get; set; }

    public string Form { get; set; } = "";

    public string Strength { get; set; } = "";

    public int UseCount { get; set; } = 1;

    public DateTime LastUsedAt { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;
}
