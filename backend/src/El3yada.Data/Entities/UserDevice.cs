using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class UserDevice
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string DeviceId { get; set; } = null!;

    public string Platform { get; set; } = null!;

    public string? FcmToken { get; set; }

    public string AppVersion { get; set; } = null!;

    public DateTime UpdatedAt { get; set; }

    public virtual User User { get; set; } = null!;
}
