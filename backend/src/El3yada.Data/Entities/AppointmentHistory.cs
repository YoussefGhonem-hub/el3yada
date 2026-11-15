using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class AppointmentHistory
{
    public Guid Id { get; set; }

    public Guid AppointmentId { get; set; }

    public DateTime At { get; set; }

    public Guid? ByUserId { get; set; }

    public string ByRole { get; set; } = null!;

    public string Action { get; set; } = null!;

    public string? FromValue { get; set; }

    public string? ToValue { get; set; }

    public string? Reason { get; set; }

    public virtual Appointment Appointment { get; set; } = null!;

    public virtual User? ByUser { get; set; }
}
