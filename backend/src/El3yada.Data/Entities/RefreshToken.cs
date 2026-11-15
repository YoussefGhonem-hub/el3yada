using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class RefreshToken
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    /// <summary>
    /// The sign-in this token belongs to. Every token made by rotating it keeps the same family,
    /// so a rotated token that comes back can revoke the whole chain at once.
    /// </summary>
    public Guid FamilyId { get; set; }

    public string? DeviceId { get; set; }

    public byte[] TokenHash { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime ExpiresAt { get; set; }

    public DateTime? RevokedAt { get; set; }

    public Guid? ReplacedByTokenId { get; set; }

    public string? CreatedByIp { get; set; }

    public virtual User User { get; set; } = null!;
}
