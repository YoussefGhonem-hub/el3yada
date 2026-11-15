using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class BranchPhoto
{
    public Guid Id { get; set; }

    public Guid BranchId { get; set; }

    public string Path { get; set; } = null!;

    public int SortOrder { get; set; }

    public virtual Branch Branch { get; set; } = null!;
}
