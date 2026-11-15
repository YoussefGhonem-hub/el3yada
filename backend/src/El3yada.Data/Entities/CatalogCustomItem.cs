using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class CatalogCustomItem
{
    public Guid Id { get; set; }

    public string Type { get; set; } = null!;

    public string NameEn { get; set; } = null!;

    public string? NameAr { get; set; }

    public string? ActiveIngredient { get; set; }

    public string? DrugGroupId { get; set; }

    public string? Route { get; set; }

    public string? LoincCode { get; set; }

    public string? AliasesJson { get; set; }

    public bool Active { get; set; } = true;

    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;
}
