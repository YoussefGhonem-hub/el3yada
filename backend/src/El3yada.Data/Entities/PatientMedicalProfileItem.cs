using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PatientMedicalProfileItem
{
    public Guid Id { get; set; }

    public Guid LinkId { get; set; }

    public string Kind { get; set; } = null!;

    public string Text { get; set; } = null!;

    public int SortOrder { get; set; }

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    /// <summary>Removed from the profile (BR-P8: medical data is never hard-deleted). Hidden by a query filter.</summary>
    public DateTime? DeletedAt { get; set; }

    public Guid? DeletedBy { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual DoctorPatient Link { get; set; } = null!;
}
