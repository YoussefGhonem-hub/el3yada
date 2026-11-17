using System;

namespace El3yada.Data.Entities;

/// <summary>
/// A medical file uploaded with <c>uploadFile</c> and waiting for <c>createRecord</c> (backend/docs/api-phase-3-files.md).
/// Already checked and optimized. Unclaimed uploads are deleted, with their files, after <see cref="ExpiresAt"/>.
/// </summary>
public partial class PendingUpload
{
    public Guid Id { get; set; }

    /// <summary>The clinic: only its doctor and assistants can use the upload.</summary>
    public Guid DoctorId { get; set; }

    public Guid UploadedBy { get; set; }

    /// <summary>uploads/{doctorId}/{uploadId}.{ext}</summary>
    public string Path { get; set; } = null!;

    public string? ThumbPath { get; set; }

    /// <summary>The uploaded name, for display only.</summary>
    public string FileName { get; set; } = null!;

    /// <summary>What users get when they download it.</summary>
    public string MimeType { get; set; } = null!;

    /// <summary>The size users download.</summary>
    public long SizeBytes { get; set; }

    /// <summary>The size on disk (smaller when compressed).</summary>
    public long StoredSizeBytes { get; set; }

    /// <summary>The size as uploaded, before optimization.</summary>
    public long OriginalSizeBytes { get; set; }

    public int? PageCount { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime ExpiresAt { get; set; }
}
