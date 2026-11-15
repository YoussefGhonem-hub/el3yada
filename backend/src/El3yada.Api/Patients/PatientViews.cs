namespace El3yada.Api.Patients;

/// <summary>
/// The patient's latest non-deleted session with this doctor. <c>day</c> is its Cairo date and
/// <c>daysAgo</c> the Cairo days since (0 = today), so the app needn't know the time zone (AC-4).
/// </summary>
public sealed record LastVisitView(
    Guid SessionId, DateTime At, DateOnly Day, int DaysAgo, string Type, Guid BranchId, string BranchNameAr, string? BranchNameEn);

/// <summary>Visit counters of one doctor–patient link (non-deleted sessions only).</summary>
public sealed record PatientVisitsView(
    DateTime? FirstVisitAt,
    LastVisitView? LastVisit,
    int Total,
    int Examinations,
    int Consultations,
    int ConsultationsSinceExam);

/// <summary>Non-deleted medical files this doctor's clinic added, per D6 sub-tab (Phase 3 adds them).</summary>
public sealed record PatientFilesView(int Prescription, int Lab, int Radiology, int Other, int Total);

/// <summary>
/// D6 header and file summary (<c>GET /api/patients/{patientId}</c>), also returned by every patient write.
/// <c>totalPaidPiasters</c> is null without <c>revenueView</c> and <c>hasAllergies</c> null without
/// <c>clinicalView</c>: null means hidden, never "none".
/// </summary>
public sealed record PatientDetailView(
    Guid PatientId,
    int FileNumber,
    string FullName,
    string Phone,
    string Gender,
    DateOnly DateOfBirth,
    bool DateOfBirthEstimated,
    int AgeYears,
    string? NationalId,
    string? Address,
    string? BloodType,
    string? EmergencyContactName,
    string? EmergencyContactPhone,
    string AccountStatus,
    bool Archived,
    DateTime? ArchivedAt,
    DateTime LinkedAt,
    PatientVisitsView Visits,
    int? TotalPaidPiasters,
    bool? HasAllergies,
    PatientFilesView Files,
    int PrescriptionCount,
    object? NextBooking,
    int NoShowCount);

/// <summary>createPatient answer. <c>temporaryPassword</c> is only for a new account, shown once (BR-P4).</summary>
public sealed record CreatedPatientResponse(bool Linked, string? TemporaryPassword, PatientDetailView Patient);

/// <summary>resetPatientPassword answer, shown once (BR-P5).</summary>
public sealed record PatientPasswordResetResponse(Guid PatientId, string TemporaryPassword);

/// <summary><c>new</c>, <c>linkedToYou</c> or <c>existsElsewhere</c>. Only <c>linkedToYou</c> has the other fields.</summary>
public sealed record PhoneLookupView(string Status, Guid? PatientId = null, int? FileNumber = null, string? FullName = null, bool? Archived = null);

public static class PhoneLookupStatuses
{
    public const string New = "new";
    public const string LinkedToYou = "linkedToYou";
    public const string ExistsElsewhere = "existsElsewhere";
}

public sealed record ProfileItemView(Guid Id, string Text);

/// <summary>The medical profile of one link (D6 Overview, D7). Allergies first: the app shows them in red.</summary>
public sealed record MedicalProfileView(
    Guid PatientId,
    bool HasAllergies,
    IReadOnlyList<ProfileItemView> Allergies,
    IReadOnlyList<ProfileItemView> ChronicDiseases,
    IReadOnlyList<ProfileItemView> CurrentMedications,
    IReadOnlyList<ProfileItemView> Surgeries,
    string? FamilyHistory,
    string? Notes);

/// <summary>
/// One D4 row. <c>totalPaidPiasters</c> is null without <c>revenueView</c>; <c>hasAllergies</c> and
/// <c>chronicDiseases</c> are null without <c>clinicalView</c>.
/// </summary>
public sealed record PatientRegisterRow(
    Guid PatientId,
    int FileNumber,
    string FullName,
    string Phone,
    string Gender,
    DateOnly DateOfBirth,
    bool DateOfBirthEstimated,
    int AgeYears,
    PatientVisitsView Visits,
    int? TotalPaidPiasters,
    object? NextBooking,
    int NoShowCount,
    int FilesCount,
    bool? HasAllergies,
    IReadOnlyList<string>? ChronicDiseases,
    bool Archived,
    DateTime LinkedAt);
