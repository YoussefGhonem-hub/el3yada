using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class DoctorAdminNote
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public string Text { get; set; } = null!;

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual Doctor Doctor { get; set; } = null!;
}
