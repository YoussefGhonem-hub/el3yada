using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Branch
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public string NameAr { get; set; } = null!;

    public string? NameEn { get; set; }

    public string? Description { get; set; }

    public bool IsDefault { get; set; }

    public string Governorate { get; set; } = null!;

    public string City { get; set; } = null!;

    public string? Area { get; set; }

    /// <summary>«العنوان بالتفصيل»: street, building, floor and apartment as the doctor writes them (up to 300 characters).</summary>
    public string AddressDetails { get; set; } = null!;

    public string? Landmark { get; set; }

    /// <summary>«لينك جوجل ماب»: a Google Maps link (up to 500 characters), checked by form only.</summary>
    public string? MapUrl { get; set; }

    public string? Email { get; set; }

    public int? ExaminationPricePiasters { get; set; }

    public int? ConsultationPricePiasters { get; set; }

    public string PaymentMethodsJson { get; set; } = "[\"cash\"]";

    public string? AmenitiesJson { get; set; }

    public string Status { get; set; } = "active";

    public string? ClosedMessage { get; set; }

    public DateOnly? ReopenDate { get; set; }

    public string BookingMode { get; set; } = "queue";

    public int SlotMinutes { get; set; } = 15;

    public byte ExamSlots { get; set; } = (byte)1;

    public byte ConsultationSlots { get; set; } = (byte)1;

    public int DefaultCapacity { get; set; } = 30;

    public int AvgVisitMinutes { get; set; } = 10;

    public bool SelfBooking { get; set; } = true;

    public bool AutoConfirm { get; set; } = true;

    public int WindowDays { get; set; } = 30;

    public int MinNoticeMinutes { get; set; } = 60;

    public bool SameDay { get; set; } = true;

    public int FreeCancelMinutes { get; set; } = 120;

    public int MaxReschedules { get; set; } = 2;

    public int MaxUpcomingPerPatient { get; set; } = 1;

    public int NoShowLimitCount { get; set; } = 3;

    public int NoShowLimitDays { get; set; } = 90;

    public string ReminderMinutesJson { get; set; } = "[1440,120]";

    public bool StaffOverbooking { get; set; } = true;

    public bool WaitingOrderByArrival { get; set; }

    public int WaitAmberMinutes { get; set; } = 20;

    public int WaitRedMinutes { get; set; } = 40;

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();

    public virtual ICollection<BranchClosure> BranchClosures { get; set; } = new List<BranchClosure>();

    public virtual ICollection<BranchDateOverride> BranchDateOverrides { get; set; } = new List<BranchDateOverride>();

    public virtual ICollection<BranchDayState> BranchDayStates { get; set; } = new List<BranchDayState>();

    public virtual ICollection<BranchPeriod> BranchPeriods { get; set; } = new List<BranchPeriod>();

    public virtual ICollection<BranchPhone> BranchPhones { get; set; } = new List<BranchPhone>();

    public virtual ICollection<BranchPhoto> BranchPhotos { get; set; } = new List<BranchPhoto>();

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual ICollection<DoctorDailyMetric> DoctorDailyMetrics { get; set; } = new List<DoctorDailyMetric>();

    public virtual ICollection<DoctorPatient> DoctorPatients { get; set; } = new List<DoctorPatient>();

    public virtual ICollection<Doctor> Doctors { get; set; } = new List<Doctor>();

    public virtual ICollection<InvoiceBranchBreakdown> InvoiceBranchBreakdowns { get; set; } = new List<InvoiceBranchBreakdown>();

    public virtual ICollection<PriceHistory> PriceHistories { get; set; } = new List<PriceHistory>();

    public virtual ICollection<Session> Sessions { get; set; } = new List<Session>();

    public virtual ICollection<Assistant> Assistants { get; set; } = new List<Assistant>();
}
