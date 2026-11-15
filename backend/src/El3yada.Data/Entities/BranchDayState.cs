using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class BranchDayState
{
    public Guid BranchId { get; set; }

    public DateOnly LocalDate { get; set; }

    public TimeOnly PeriodStartLocal { get; set; }

    public int? NowServingNumber { get; set; }

    public int? DelayMinutes { get; set; }

    public DateTime? DelayNoticeSentAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual Branch Branch { get; set; } = null!;
}
