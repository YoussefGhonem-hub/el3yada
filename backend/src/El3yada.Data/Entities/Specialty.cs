using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Specialty
{
    public Guid Id { get; set; }

    public string NameAr { get; set; } = null!;

    public string NameEn { get; set; } = null!;

    public bool Active { get; set; } = true;

    public int SortOrder { get; set; }

    public bool IncludeGeneral { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual ICollection<Doctor> Doctors { get; set; } = new List<Doctor>();

    public virtual ICollection<SpecialtyProfileItem> SpecialtyProfileItems { get; set; } = new List<SpecialtyProfileItem>();

    public virtual ICollection<Doctor> DoctorsNavigation { get; set; } = new List<Doctor>();
}
