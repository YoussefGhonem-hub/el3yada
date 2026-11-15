using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class DoctorDailyMetric
{
    public Guid DoctorId { get; set; }

    public Guid BranchId { get; set; }

    public DateOnly Date { get; set; }

    public int ExamCount { get; set; }

    public int ConsultationCount { get; set; }

    public int PatientRevenuePiasters { get; set; }

    public int DiscountPiasters { get; set; }

    public int PlatformFeesPiasters { get; set; }

    public int UniquePatients { get; set; }

    public int NewPatients { get; set; }

    public int FreeVisits { get; set; }

    public int Bookings { get; set; }

    public int CompletedBookings { get; set; }

    public int NoShows { get; set; }

    public int Cancellations { get; set; }

    public int AppBookings { get; set; }

    public int WalkIns { get; set; }

    public string VisitsByHourJson { get; set; } = "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]";

    public decimal? AvgWaitMinutes { get; set; }

    public DateTime BuiltAt { get; set; }

    public virtual Branch Branch { get; set; } = null!;

    public virtual Doctor Doctor { get; set; } = null!;
}
