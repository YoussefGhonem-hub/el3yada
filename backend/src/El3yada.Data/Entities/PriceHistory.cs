using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PriceHistory
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid? BranchId { get; set; }

    public int? BeforeExaminationPiasters { get; set; }

    public int? BeforeConsultationPiasters { get; set; }

    public int? AfterExaminationPiasters { get; set; }

    public int? AfterConsultationPiasters { get; set; }

    public Guid ChangedBy { get; set; }

    public string ChangedByRole { get; set; } = null!;

    public DateTime ChangedAt { get; set; }

    public virtual Branch? Branch { get; set; }

    public virtual User ChangedByNavigation { get; set; } = null!;

    public virtual Doctor Doctor { get; set; } = null!;
}
