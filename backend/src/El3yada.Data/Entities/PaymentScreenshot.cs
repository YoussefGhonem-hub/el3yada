using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PaymentScreenshot
{
    public Guid Id { get; set; }

    public Guid PaymentId { get; set; }

    public string Path { get; set; } = null!;

    public byte SortOrder { get; set; }

    public virtual Payment Payment { get; set; } = null!;
}
