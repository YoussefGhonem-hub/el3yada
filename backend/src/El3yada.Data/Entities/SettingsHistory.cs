using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class SettingsHistory
{
    public Guid Id { get; set; }

    public string Field { get; set; } = null!;

    public string? BeforeValue { get; set; }

    public string? AfterValue { get; set; }

    public Guid ChangedBy { get; set; }

    public DateTime ChangedAt { get; set; }

    public virtual User ChangedByNavigation { get; set; } = null!;
}
