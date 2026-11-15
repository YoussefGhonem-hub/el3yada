using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class MonthlyStat
{
    public Guid DoctorId { get; set; }

    public string MonthKey { get; set; } = null!;

    public int ExamCount { get; set; }

    public int ConsultationCount { get; set; }

    public int AmountPiasters { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;
}
