using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Notification
{
    public Guid Id { get; set; }

    public Guid RecipientUserId { get; set; }

    public string Type { get; set; } = null!;

    public string TitleAr { get; set; } = null!;

    public string TitleEn { get; set; } = null!;

    public string BodyAr { get; set; } = null!;

    public string BodyEn { get; set; } = null!;

    public string? Route { get; set; }

    public string? DataJson { get; set; }

    public bool IsRead { get; set; }

    public DateTime? ReadAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual User RecipientUser { get; set; } = null!;
}
