using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class InvoiceStatusHistory
{
    public Guid Id { get; set; }

    public Guid InvoiceId { get; set; }

    public string Status { get; set; } = null!;

    public string? Note { get; set; }

    public Guid? ChangedBy { get; set; }

    public DateTime ChangedAt { get; set; }

    public virtual User? ChangedByNavigation { get; set; }

    public virtual Invoice Invoice { get; set; } = null!;
}
