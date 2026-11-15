using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Assistant
{
    public Guid UserId { get; set; }

    public Guid DoctorId { get; set; }

    public string FullName { get; set; } = null!;

    public string Phone { get; set; } = null!;

    public string Preset { get; set; } = "custom";

    public bool AllBranches { get; set; }

    public bool PatientsManage { get; set; }

    public bool PatientsResetPassword { get; set; }

    public bool SessionsCreate { get; set; }

    public bool SessionsDelete { get; set; }

    public bool ClinicalView { get; set; }

    public bool ClinicalEditProfile { get; set; }

    public bool FilesManage { get; set; }

    public bool PrescriptionsPrint { get; set; }

    public bool PrescriptionsDraft { get; set; }

    public bool Chat { get; set; }

    public bool BillingView { get; set; }

    public bool BillingPay { get; set; }

    public bool AppointmentsView { get; set; }

    public bool AppointmentsManage { get; set; }

    public bool ScheduleManage { get; set; }

    public bool RevenueView { get; set; }

    public bool PricesManage { get; set; }

    public string Status { get; set; } = "active";

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public DateTime? LastActiveAt { get; set; }

    public DateTime? RemovedAt { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual User User { get; set; } = null!;

    public virtual ICollection<Branch> Branches { get; set; } = new List<Branch>();
}
