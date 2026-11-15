using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class MedicalRecord
{
    public Guid Id { get; set; }

    public Guid DoctorId { get; set; }

    public Guid PatientId { get; set; }

    public Guid? SessionId { get; set; }

    public string Category { get; set; } = null!;

    public string? OtherType { get; set; }

    public string? OtherTypeText { get; set; }

    public string Title { get; set; } = null!;

    public DateOnly DocumentDate { get; set; }

    public string? Notes { get; set; }

    public string Source { get; set; } = null!;

    public Guid? SourceChatMessageId { get; set; }

    public Guid CreatedBy { get; set; }

    public string CreatedByRole { get; set; } = null!;

    public DateTime? PatientSeenAt { get; set; }

    public bool Deleted { get; set; }

    public DateTime? DeletedAt { get; set; }

    public Guid? DeletedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }

    public virtual User CreatedByNavigation { get; set; } = null!;

    public virtual User? DeletedByNavigation { get; set; }

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual ICollection<MedicalRecordAttachment> MedicalRecordAttachments { get; set; } = new List<MedicalRecordAttachment>();

    public virtual Patient Patient { get; set; } = null!;

    public virtual Session? Session { get; set; }

    public virtual ChatMessage? SourceChatMessage { get; set; }
}
