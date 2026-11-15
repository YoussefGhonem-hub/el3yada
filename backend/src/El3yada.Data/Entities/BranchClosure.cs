using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class BranchClosure
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid? BranchId { get; set; }

    public DateTime FromLocal { get; set; }

    public DateTime ToLocal { get; set; }

    public string? Reason { get; set; }

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Branch? Branch { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual Doctor Doctor { get; set; } = null!;
}
