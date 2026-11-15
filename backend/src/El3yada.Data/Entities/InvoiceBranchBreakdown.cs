using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class InvoiceBranchBreakdown
{
    public Guid InvoiceId { get; set; }

    public Guid BranchId { get; set; }

    public int ExamCount { get; set; }

    public int ConsultationCount { get; set; }

    public int AmountPiasters { get; set; }

    public virtual Branch Branch { get; set; } = null!;

    public virtual Invoice Invoice { get; set; } = null!;
}
