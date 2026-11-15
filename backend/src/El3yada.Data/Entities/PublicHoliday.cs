using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PublicHoliday
{
    public Guid Id { get; set; }

    public DateOnly Date { get; set; }

    public string NameAr { get; set; } = null!;

    public string NameEn { get; set; } = null!;
}
