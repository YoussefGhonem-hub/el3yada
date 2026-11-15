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

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual DoctorPatient Link { get; set; } = null!;
}
