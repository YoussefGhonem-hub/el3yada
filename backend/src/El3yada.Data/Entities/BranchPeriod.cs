using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class BranchPeriod
{
    public Guid Id { get; set; }

    public Guid BranchId { get; set; }

    public byte Weekday { get; set; }

    public TimeOnly StartLocal { get; set; }

    public TimeOnly EndLocal { get; set; }

    public bool EndsNextDay { get; set; }

    public string? Label { get; set; }

    public int? Capacity { get; set; }

    public virtual Branch Branch { get; set; } = null!;
}
