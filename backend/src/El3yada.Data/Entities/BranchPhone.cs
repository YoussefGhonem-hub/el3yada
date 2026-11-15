using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class BranchPhone
{
    public Guid Id { get; set; }

    public Guid BranchId { get; set; }

    public string Number { get; set; } = null!;

    public string Label { get; set; } = "reception";

    public bool IsWhatsapp { get; set; }

    public int SortOrder { get; set; }

    public virtual Branch Branch { get; set; } = null!;
}
