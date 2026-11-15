using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class InvoiceAdjustment
{
    public Guid Id { get; set; }

    public Guid InvoiceId { get; set; }

    public int AmountPiasters { get; set; }

    public string Reason { get; set; } = null!;

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual Invoice Invoice { get; set; } = null!;
}
