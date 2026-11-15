using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class ChatMessage
{
    public Guid Id { get; set; }

    public Guid ChatId { get; set; }

    public Guid SenderId { get; set; }

    public string SenderRole { get; set; } = null!;

    public string SenderName { get; set; } = null!;

    public string Type { get; set; } = null!;

    public string? Text { get; set; }

    public string? AttachmentPath { get; set; }

    public string? AttachmentFileName { get; set; }

    public string? AttachmentMimeType { get; set; }

    public long? AttachmentSizeBytes { get; set; }

    public DateTime? ReadAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Chat Chat { get; set; } = null!;

    public virtual ICollection<MedicalRecord> MedicalRecords { get; set; } = new List<MedicalRecord>();

    public virtual User Sender { get; set; } = null!;
}
