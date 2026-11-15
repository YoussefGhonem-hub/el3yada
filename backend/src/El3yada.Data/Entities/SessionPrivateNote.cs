using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class SessionPrivateNote
{
    public Guid SessionId { get; set; }

    public string Text { get; set; } = null!;

    public DateTime UpdatedAt { get; set; }

    public virtual Session Session { get; set; } = null!;
}
