using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class MedicalRecordAttachment
{
    public Guid Id { get; set; }

    public Guid RecordId { get; set; }

    public string Path { get; set; } = null!;

    public string FileName { get; set; } = null!;

    public string MimeType { get; set; } = null!;

    public long SizeBytes { get; set; }

    public int? PageCount { get; set; }

    public string? ThumbPath { get; set; }

    public int SortOrder { get; set; }

    public virtual MedicalRecord Record { get; set; } = null!;
}
