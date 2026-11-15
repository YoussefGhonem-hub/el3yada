using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class ChatReadState
{
    public Guid ChatId { get; set; }

    public Guid UserId { get; set; }

    public int UnreadCount { get; set; }

    public DateTime? LastReadAt { get; set; }

    public virtual Chat Chat { get; set; } = null!;

    public virtual User User { get; set; } = null!;
}
