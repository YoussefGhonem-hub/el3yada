using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class PrescriptionMedicationItem
{
    public Guid Id { get; set; }

    public Guid PrescriptionId { get; set; }

    public int SortOrder { get; set; }

    public string DrugName { get; set; } = null!;

    public string? ActiveIngredient { get; set; }

    public string? CatalogId { get; set; }

    public string? Form { get; set; }

    public string? Strength { get; set; }

    public string? Dose { get; set; }

    public string? Frequency { get; set; }

    public string? Timing { get; set; }

    public string? Duration { get; set; }

    public string? Instructions { get; set; }

    public virtual Prescription Prescription { get; set; } = null!;
}
