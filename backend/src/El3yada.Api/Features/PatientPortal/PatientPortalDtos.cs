namespace El3yada.Api.Features.PatientPortal;

// Responses of the patient app endpoints (P1–P10, P14). They hold only what spec 9.4 lets a
// patient read: never private notes, drafts, deleted rows, fees or staff-only fields.

public sealed record DoctorRef(Guid Id, string FullName, string? FullNameEn, string Title, string? TitleEn);

public sealed record BranchRef(Guid Id, string NameAr, string? NameEn);

public sealed record SpecialtyRef(Guid Id, string NameAr, string NameEn);

/// <summary>Items the patient hasn't opened yet ("New" badges, P1).</summary>
public sealed record NewCounts(int Visits, int Prescriptions, int Files);

// P2: my doctors
public sealed record MyDoctorDto(
    DoctorRef Doctor,
    SpecialtyRef Specialty,
    string DoctorStatus,
    int FileNumber,
    DateTime LinkedAt,
    DateTime? LastVisitAt,
    BranchRef? DefaultBranch,
    string? DefaultBranchArea,
    NewCounts New);

// P3: doctor info
public sealed record DoctorInfoDto(
    DoctorRef Doctor,
    SpecialtyRef Specialty,
    string? DegreesAr,
    string? DegreesEn,
    string DoctorStatus,
    int FileNumber,
    IReadOnlyList<BranchInfoDto> Branches);

public sealed record AddressDto(
    string Governorate, string City, string? Area, string Details, string? Landmark, string? MapUrl);

public sealed record BranchPhoneDto(string Number, string Label, bool IsWhatsapp);

public sealed record WorkingPeriodDto(int Weekday, TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label);

/// <summary>Visit prices shown to patients (BR-PR2, BR-PR6): the branch's own, or the doctor's. Null = ask the clinic.</summary>
public sealed record VisitPricesDto(int? ExaminationPiasters, int? ConsultationPiasters);

public sealed record BranchInfoDto(
    Guid Id,
    string NameAr,
    string? NameEn,
    string? Description,
    bool IsDefault,
    string Status,
    string? ClosedMessage,
    DateOnly? ReopenDate,
    AddressDto Address,
    string? Email,
    IReadOnlyList<BranchPhoneDto> Phones,
    IReadOnlyList<WorkingPeriodDto> WorkingHours,
    VisitPricesDto Prices,
    IReadOnlyList<string> PaymentMethods,
    IReadOnlyList<string> Amenities);

// P4 / P5: visits
public sealed record VisitListItemDto(
    Guid Id,
    DoctorRef Doctor,
    BranchRef Branch,
    string Type,
    DateTime At,
    DateOnly DayKey,
    string? DiagnosisSnippet,
    bool IsNew);

/// <summary>P4 branch filter: a branch the patient has visits in, with its doctor and how many visits.</summary>
public sealed record VisitBranchOptionDto(BranchRef Branch, DoctorRef Doctor, int Visits);

public sealed record VitalsDto(
    short? BpSys, short? BpDia, short? Pulse, decimal? TempC,
    decimal? WeightKg, decimal? HeightCm, short? Glucose);

public sealed record VisitBranchDto(Guid Id, string NameAr, string? NameEn, AddressDto Address, IReadOnlyList<BranchPhoneDto> Phones);

public sealed record VisitDetailDto(
    Guid Id,
    DoctorRef Doctor,
    VisitBranchDto Branch,
    string Type,
    DateTime At,
    DateOnly DayKey,
    string? ChiefComplaint,
    string? Findings,
    VitalsDto Vitals,
    string? Diagnosis,
    string? PatientNotes,
    DateOnly? FollowUpDate,
    bool IsNew,
    IReadOnlyList<PrescriptionListItemDto> Prescriptions,
    IReadOnlyList<RecordListItemDto> Files);

// P6 / P7: prescriptions
public sealed record PrescriptionListItemDto(
    Guid Id,
    string Kind,
    string Status,
    DoctorRef Doctor,
    Guid SessionId,
    DateTime? SentAt,
    DateTime? CancelledAt,
    int ItemCount,
    bool IsNew);

public sealed record MedicationItemDto(
    string DrugName, string? ActiveIngredient, string? Form, string? Strength,
    string? Dose, string? Frequency, string? Timing, string? Duration, string? Instructions);

public sealed record InvestigationItemDto(string Category, string Name, string? Notes);

public sealed record PrescriptionDetailDto(
    Guid Id,
    string Kind,
    string Status,
    DoctorRef Doctor,
    Guid SessionId,
    DateOnly VisitDay,
    string? Diagnosis,
    string? Advice,
    DateTime? SentAt,
    DateTime? CancelledAt,
    string? CancelReason,
    Guid? ReplacesId,
    Guid? ReplacedById,
    bool HasPdf,
    bool IsNew,
    IReadOnlyList<MedicationItemDto> Medications,
    IReadOnlyList<InvestigationItemDto> Investigations);

// P8 / P9: medical files
public sealed record AttachmentDto(Guid Id, string FileName, string MimeType, long SizeBytes, int? PageCount, bool HasThumbnail);

public sealed record RecordListItemDto(
    Guid Id,
    DoctorRef Doctor,
    Guid? SessionId,
    string Category,
    string? OtherType,
    string? OtherTypeText,
    string Title,
    DateOnly DocumentDate,
    int AttachmentCount,
    AttachmentDto? Cover,
    bool IsNew);

public sealed record RecordDetailDto(
    Guid Id,
    DoctorRef Doctor,
    Guid? SessionId,
    string Category,
    string? OtherType,
    string? OtherTypeText,
    string Title,
    DateOnly DocumentDate,
    string? Notes,
    string Source,
    bool IsNew,
    IReadOnlyList<AttachmentDto> Attachments);

public sealed record RecordCountsDto(int Prescription, int Lab, int Radiology, int Other);

// P10: medical profile
public sealed record PersonalInfoDto(
    Guid PatientId, string FullName, string Phone, string Gender,
    DateOnly DateOfBirth, bool DateOfBirthEstimated, string? BloodType);

public sealed record DoctorMedicalProfileDto(
    DoctorRef Doctor,
    IReadOnlyList<string> Allergies,
    IReadOnlyList<string> ChronicDiseases,
    IReadOnlyList<string> CurrentMedications,
    IReadOnlyList<string> Surgeries,
    string? FamilyHistory,
    string? Notes);

public sealed record MedicalProfileDto(PersonalInfoDto Personal, IReadOnlyList<DoctorMedicalProfileDto> Doctors);

// P1: home
public sealed record FollowUpDto(DateOnly Date, DoctorRef Doctor, Guid SessionId);

public sealed record PatientHomeDto(
    string FullName,
    VisitListItemDto? LatestVisit,
    PrescriptionListItemDto? LatestPrescription,
    FollowUpDto? NextFollowUp,
    IReadOnlyList<RecordListItemDto> RecentFiles,
    NewCounts New);

// P14: account
public sealed record DeletionRequestDto(Guid Id, string Status, string? Reason, DateTime CreatedAt, DateTime? ReviewedAt, string? ReviewNote);

public sealed record PatientAccountDto(
    PersonalInfoDto Personal,
    string Locale,
    string ThemeMode,
    bool NotifyChat,
    bool NotifyReminders,
    bool NotifyShowPreview,
    DateTime? AcceptedTermsAt,
    DeletionRequestDto? DeletionRequest);

// Requests
public sealed record MarkSeenRequest(
    IReadOnlyList<Guid>? Visits,
    IReadOnlyList<Guid>? Prescriptions,
    IReadOnlyList<Guid>? Files);

public sealed record RequestAccountDeletionRequest(string? Reason);

/// <summary>Filters for the visits, prescriptions and files lists.</summary>
public sealed record PatientListQuery : Infrastructure.Paging.PageQuery
{
    public Guid? DoctorId { get; init; }
    public Guid? BranchId { get; init; }

    /// <summary>Prescriptions: <c>medication</c> or <c>investigations</c>. Files: a category.</summary>
    public string? Kind { get; init; }

    public DateOnly? From { get; init; }
    public DateOnly? To { get; init; }
}
