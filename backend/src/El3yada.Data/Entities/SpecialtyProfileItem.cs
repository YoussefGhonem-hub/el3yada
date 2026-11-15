using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class SpecialtyProfileItem
{
    public Guid Id { get; set; }

    public Guid SpecialtyId { get; set; }

    public string ItemType { get; set; } = null!;

    public string Value { get; set; } = null!;

    public virtual Specialty Specialty { get; set; } = null!;
}
