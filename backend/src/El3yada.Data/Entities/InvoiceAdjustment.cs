using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class InvoiceAdjustment
{
    public Guid Id { get; set; }

    public Guid InvoiceId { get; set; }

    public int AmountPiasters { get; set; }

    public string Reason { get; set; } = null!;

    /// <summary>The admin who added it, or null for a line the system added (fees carried from a final invoice).</summary>
    public Guid? CreatedBy { get; set; }

    /// <summary>
    /// On a line that carries the fees of sessions saved after a final invoice of this month (yyyy-MM, BR-DEL10).
    /// Null for an admin's adjustment.
    /// </summary>
    public string? CarriedMonthKey { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual User? CreatedByNavigation { get; set; }

    public virtual Invoice Invoice { get; set; } = null!;
}
