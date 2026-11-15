using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class CatalogVersion
{
    public Guid Id { get; set; }

    public int VersionNumber { get; set; }

    public int SchemaVersion { get; set; }

    public string StoragePath { get; set; } = null!;

    public string Sha256 { get; set; } = null!;

    public long SizeBytes { get; set; }

    public int DrugCount { get; set; }

    public int LabCount { get; set; }

    public int RadiologyCount { get; set; }

    public DateOnly? DrugDatasetDate { get; set; }

    public string? LoincRelease { get; set; }

    public DateTime PublishedAt { get; set; }

    public Guid PublishedBy { get; set; }

    public virtual ICollection<AppSetting> AppSettings { get; set; } = new List<AppSetting>();

    public virtual User PublishedByNavigation { get; set; } = null!;
}
