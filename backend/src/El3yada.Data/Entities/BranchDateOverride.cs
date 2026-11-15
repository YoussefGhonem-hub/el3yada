using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class BranchDateOverride
{
    public Guid Id { get; set; }

    public Guid BranchId { get; set; }

    public DateOnly Date { get; set; }

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Branch Branch { get; set; } = null!;

    public virtual ICollection<BranchDateOverridePeriod> BranchDateOverridePeriods { get; set; } = new List<BranchDateOverridePeriod>();

    public virtual User CreatedByNavigation { get; set; } = null!;
}
