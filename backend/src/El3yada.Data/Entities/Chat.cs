using System;
using System.Collections.Generic;

namespace El3yada.Data.Entities;

public partial class Chat
{
    public Guid Id { get; set; }

    public Guid LinkId { get; set; }

    public Guid DoctorId { get; set; }

    public Guid PatientId { get; set; }

    public bool Enabled { get; set; } = true;

    public string? LastMessageText { get; set; }

    public string? LastMessageType { get; set; }

    public Guid? LastMessageSenderId { get; set; }

    public DateTime? LastMessageAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual ICollection<ChatMessage> ChatMessages { get; set; } = new List<ChatMessage>();

    public virtual ICollection<ChatReadState> ChatReadStates { get; set; } = new List<ChatReadState>();

    public virtual Doctor Doctor { get; set; } = null!;

    public virtual User? LastMessageSender { get; set; }

    public virtual DoctorPatient Link { get; set; } = null!;

    public virtual Patient Patient { get; set; } = null!;
}
