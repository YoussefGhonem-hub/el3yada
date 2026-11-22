using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Patients;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// Patients of a clinic (spec 6.1; D4–D7, AS2–AS4; spec 9.1 <c>createPatient</c>, <c>updatePatientPhone</c>,
/// <c>resetPatientPassword</c>, <c>getPatientsRegister</c>). A patient is addressed by <c>patientId</c>; the
/// server finds the caller's link to them, and a patient who isn't linked to the caller's doctor is 404.
/// Contract: backend/docs/api-phase-2-patients.md.
/// </summary>
[ApiController]
[Route("api/patients")]
[Clinic]
public sealed class PatientsController(
    AppDbContext db,
    Passwords passwords,
    SessionService sessions,
    Auditor auditor,
    AccountStateCache stateCache,
    IdentifierThrottle throttle,
    TimeProvider time) : ControllerBase
{
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    private DateOnly Today => CairoTime.Today(time);

    /// <summary>
    /// D5 / D32 pre-check: is this number new, already this doctor's patient, or another clinic's patient?
    /// Nothing about another clinic's patient is returned (BR-P3).
    /// </summary>
    [HttpGet("lookupPhone")]
    [Clinic(ClinicPermissions.PatientsManage)]
    public async Task<IActionResult> LookupPhone([FromQuery] LookupPhoneQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var phone = EgyptianMobile.Normalize(query.Phone)!;
        var patient = await db.Patients.AsNoTracking()
            .Where(p => p.Phone == phone)
            .Select(p => new
            {
                p.Id,
                Link = p.DoctorPatients
                    .Where(l => l.DoctorId == caller.DoctorId)
                    .Select(l => new { l.FileNumber, l.PatientName, l.Archived })
                    .FirstOrDefault(),
            })
            .SingleOrDefaultAsync(cancellationToken);

        Response.Headers.CacheControl = "no-store";
        return Ok(patient switch
        {
            null => new PhoneLookupView(PhoneLookupStatuses.New),
            { Link: null } => new PhoneLookupView(PhoneLookupStatuses.ExistsElsewhere),
            { Link: { } link } => new PhoneLookupView(PhoneLookupStatuses.LinkedToYou, patient.Id, link.FileNumber, link.PatientName, link.Archived),
        });
    }

    /// <summary>
    /// D5 / AS3: adds a patient to the clinic in one transaction. A number that already has a patient account is
    /// linked, with that account's identity (BR-P3, <c>linked: true</c>). Otherwise a new account is made with
    /// a temporary password shown once (BR-P4). Either way the link gets the next file number (BR-P6).
    /// </summary>
    [HttpPost("createPatient")]
    [Clinic(ClinicPermissions.PatientsManage, BlockedWhileSuspended = true)]
    public async Task<IActionResult> CreatePatient(CreatePatientRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var phone = EgyptianMobile.Normalize(request.Phone)!;
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                return await CreateOrLinkAsync(caller, request, phone, cancellationToken);
            }
            catch (DbUpdateException ex) when (attempt == 1 && ex.IsUniqueViolation())
            {
                // The locks make this very unlikely: another clinic created the number in between. The second
                // attempt finds that account and links it.
                db.ChangeTracker.Clear();
            }
        }
    }

    private async Task<IActionResult> CreateOrLinkAsync(
        ClinicCaller caller, CreatePatientRequest request, string phone, CancellationToken cancellationToken)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var fileNumber = await PatientLinks.LockNextFileNumberAsync(db, caller.DoctorId, cancellationToken);
        var patient = await PatientLinks.LockByPhoneAsync(db, phone, cancellationToken);
        if (patient is not null)
        {
            var existing = await db.DoctorPatients.AsNoTracking()
                .Where(l => l.DoctorId == caller.DoctorId && l.PatientId == patient.Id)
                .Select(l => (int?)l.FileNumber)
                .SingleOrDefaultAsync(cancellationToken);
            if (existing is { } number)
            {
                return this.ConflictProblem(ErrorCodes.PatientAlreadyLinked, "This number is already one of your patients.")
                    .WithFields(("patientId", patient.Id), ("fileNumber", number));
            }
        }

        var now = Now;
        var linked = patient is not null;
        string? temporaryPassword = null;
        if (patient is null)
        {
            if (PatientIdentityValidator.MissingFields(request) is { Count: > 0 } missing)
            {
                return ValidationProblems.Create(HttpContext, missing);
            }

            temporaryPassword = Passwords.GenerateTemporary();
            patient = NewPatient(caller, request, phone, temporaryPassword, now);
        }

        db.DoctorPatients.Add(new DoctorPatient
        {
            Id = Guid.NewGuid(),
            DoctorId = caller.DoctorId,
            PatientId = patient.Id,
            FileNumber = fileNumber,
            PatientName = patient.FullName,
            PatientPhone = patient.Phone,
            SearchName = SearchText.Normalize(patient.FullName),
            LinkedAt = now,
            LinkedBy = caller.UserId,
            UpdatedAt = now,
        });
        auditor.AddClinic(
            caller, linked ? AuditActions.PatientLinked : AuditActions.PatientCreated, AuditTargets.Patient, patient.Id,
            new { fileNumber }, patient.Id);
        await db.SaveChangesAsync(cancellationToken);
        await PatientLinks.TakeFileNumberAsync(db, caller.DoctorId, fileNumber, cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        var view = await PatientQueries.DetailAsync(db, caller, patient.Id, Today, cancellationToken);
        Response.Headers.CacheControl = "no-store";
        return StatusCode(StatusCodes.Status201Created, new CreatedPatientResponse(linked, temporaryPassword, view!));
    }

    /// <summary>A new patient account (role patient, BR-P4) with its Patients row, added to the context.</summary>
    private Patient NewPatient(ClinicCaller caller, CreatePatientRequest request, string phone, string temporaryPassword, DateTime now)
    {
        var name = Text.CollapseSpaces(request.FullName!);
        var user = new User
        {
            Id = Guid.NewGuid(),
            Role = Roles.Patient,
            Status = AccountStatuses.Active,
            DisplayName = name,
            Phone = phone,
            SecurityStamp = Guid.NewGuid(),
            MustChangePassword = true,
            CreatedAt = now,
            UpdatedAt = now,
        };
        user.PasswordHash = passwords.Hash(user, temporaryPassword);
        var patient = new Patient
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Phone = phone,
            CreatedByDoctorId = caller.DoctorId,
            Status = PatientStatuses.Active,
            CreatedAt = now,
            UpdatedAt = now,
        };
        ApplyIdentity(patient, request, Today, details: true);
        db.Users.Add(user);
        db.Patients.Add(patient);
        return patient;
    }

    /// <summary>D6 header and file summary. Any clinic caller (AS4: the profile is doctor-wide).</summary>
    [HttpGet("{patientId:guid}")]
    public async Task<IActionResult> Get(Guid patientId, CancellationToken cancellationToken)
    {
        var view = await PatientQueries.DetailAsync(db, HttpContext.Clinic(), patientId, Today, cancellationToken);
        return view is null ? this.NotFoundProblem() : Ok(view);
    }

    /// <summary>
    /// D7 identity fields (not the phone). The identity is one account shared by every clinic the patient is
    /// linked to, so the name is copied to every link (PatientName, SearchName).
    /// </summary>
    [HttpPost("updatePatient")]
    [Clinic(ClinicPermissions.PatientsManage)]
    public async Task<IActionResult> UpdatePatient(UpdatePatientRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = request.PatientId!.Value;
        if (!await PatientLinks.ExistsAsync(db, caller.DoctorId, patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var patient = await db.Patients.Include(p => p.User).SingleAsync(p => p.Id == patientId, cancellationToken);
        if (patient.Status == "deleted")
        {
            // The identity was erased (spec 6.17): the clinic keeps the record under «مريض محذوف».
            return this.ConflictProblem(ErrorCodes.AccountDeleted, "This patient's account was deleted.");
        }

        var before = IdentityFields(patient);
        // BR-P3: only the clinic that created the account keeps its optional details; others leave them as they are.
        ApplyIdentity(patient, request, Today, details: patient.CreatedByDoctorId == caller.DoctorId);
        var after = IdentityFields(patient);
        var changed = before.Keys.Where(key => !Equals(before[key], after[key])).ToList();
        if (changed.Count > 0)
        {
            var now = Now;
            patient.UpdatedAt = now;
            patient.User.DisplayName = patient.FullName;
            patient.User.UpdatedAt = now;
            auditor.AddClinic(caller, AuditActions.PatientUpdated, AuditTargets.Patient, patientId, new { fields = changed }, patientId);
            await db.SaveChangesAsync(cancellationToken);
            if (changed.Contains("fullName"))
            {
                var searchName = SearchText.Normalize(patient.FullName);
                await db.DoctorPatients.Where(l => l.PatientId == patientId)
                    .ExecuteUpdateAsync(set => set
                        .SetProperty(l => l.PatientName, patient.FullName)
                        .SetProperty(l => l.SearchName, searchName)
                        .SetProperty(l => l.UpdatedAt, now), cancellationToken);
            }
        }

        await transaction.CommitAsync(cancellationToken);
        stateCache.Invalidate(patient.UserId);
        return Ok(await PatientQueries.DetailAsync(db, caller, patientId, Today, cancellationToken));
    }

    /// <summary>
    /// D7 phone change (spec 9.1 <c>updatePatientPhone</c>): the number is the patient's login, unique among
    /// patient accounts (BR-P2). Updates the account, the patient and every link.
    /// </summary>
    [HttpPost("updatePatientPhone")]
    [Clinic(ClinicPermissions.PatientsManage)]
    public async Task<IActionResult> UpdatePatientPhone(UpdatePatientPhoneRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = request.PatientId!.Value;
        var phone = EgyptianMobile.Normalize(request.Phone)!;
        if (!await PatientLinks.ExistsAsync(db, caller.DoctorId, patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var patient = await PatientLinks.LockPatientAsync(db, patientId, cancellationToken);
        if (await DeletionRefusalAsync(patient.UserId, cancellationToken) is { } refusal)
        {
            return refusal;
        }

        if (patient.Phone != phone)
        {
            if (await db.Patients.AnyAsync(p => p.Phone == phone && p.Id != patientId, cancellationToken))
            {
                return PhoneTaken();
            }

            var now = Now;
            var user = await db.Users.SingleAsync(u => u.Id == patient.UserId, cancellationToken);
            patient.Phone = phone;
            patient.UpdatedAt = now;
            user.Phone = phone;
            user.UpdatedAt = now;
            auditor.AddClinic(caller, AuditActions.PatientPhoneChanged, AuditTargets.Patient, patientId, patientId: patientId);
            try
            {
                await db.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException ex) when (ex.IsUniqueViolation("UQ_Patients_Phone") || ex.IsUniqueViolation("UQ_Users_PatientPhone"))
            {
                return PhoneTaken();
            }

            await db.DoctorPatients.Where(l => l.PatientId == patientId)
                .ExecuteUpdateAsync(set => set.SetProperty(l => l.PatientPhone, phone).SetProperty(l => l.UpdatedAt, now), cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            stateCache.Invalidate(patient.UserId);
        }

        return Ok(await PatientQueries.DetailAsync(db, caller, patientId, Today, cancellationToken));

        ObjectResult PhoneTaken() =>
            this.ConflictProblem(ErrorCodes.PatientPhoneTaken, "Another patient account already uses this number.");
    }

    /// <summary>
    /// BR-P5: a new temporary password, shown once. The patient must change it at the next sign-in, and every
    /// device they are signed in on is signed out.
    /// </summary>
    [HttpPost("resetPatientPassword")]
    [Clinic(ClinicPermissions.PatientsResetPassword)]
    public async Task<IActionResult> ResetPatientPassword(PatientIdRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = request.PatientId!.Value;
        if (!await PatientLinks.ExistsAsync(db, caller.DoctorId, patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var user = await db.Users.SingleAsync(u => u.Patient != null && u.Patient.Id == patientId, cancellationToken);
        if (await DeletionRefusalAsync(user.Id, cancellationToken) is { } refusal)
        {
            return refusal;
        }

        var temporaryPassword = Passwords.GenerateTemporary();
        user.PasswordHash = passwords.Hash(user, temporaryPassword);
        user.MustChangePassword = true;
        // The patient may have locked the account by guessing; the doctor's new password should work at once.
        user.AccessFailedCount = 0;
        user.LockoutEndAt = null;
        auditor.AddClinic(caller, AuditActions.PatientPasswordReset, AuditTargets.Patient, patientId, patientId: patientId);
        await sessions.SignOutEverywhereAsync(user, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        // Again after the commit, so a request in between can't cache the old security stamp.
        stateCache.Invalidate(user.Id);
        throttle.ClearLoginBlock(user.Phone!);

        Response.Headers.CacheControl = "no-store";
        return Ok(new PatientPasswordResetResponse(patientId, temporaryPassword));
    }

    /// <summary>BR-P7 [S]: archived patients leave the default D4 list; nothing is deleted.</summary>
    [HttpPost("setArchived")]
    [Clinic(ClinicPermissions.PatientsManage)]
    public async Task<IActionResult> SetArchived(SetArchivedRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = request.PatientId!.Value;
        var link = await db.DoctorPatients.SingleOrDefaultAsync(
            l => l.DoctorId == caller.DoctorId && l.PatientId == patientId, cancellationToken);
        if (link is null)
        {
            return this.NotFoundProblem();
        }

        var archived = request.Archived!.Value;
        if (link.Archived != archived)
        {
            var now = Now;
            link.Archived = archived;
            link.ArchivedAt = archived ? now : null;
            link.UpdatedAt = now;
            auditor.AddClinic(
                caller, archived ? AuditActions.PatientArchived : AuditActions.PatientUnarchived, AuditTargets.Patient, patientId,
                patientId: patientId);
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(await PatientQueries.DetailAsync(db, caller, patientId, Today, cancellationToken));
    }

    /// <summary>D6 Overview, D7: the medical profile this clinic keeps for the patient (spec 6.1).</summary>
    [HttpGet("{patientId:guid}/medicalProfile")]
    [Clinic(ClinicPermissions.ClinicalView)]
    public async Task<IActionResult> GetMedicalProfile(Guid patientId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var link = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == caller.DoctorId && l.PatientId == patientId)
            .Select(l => new { l.Id, l.FamilyHistory, l.ProfileNotes })
            .SingleOrDefaultAsync(cancellationToken);
        if (link is null)
        {
            return this.NotFoundProblem();
        }

        var items = await LoadProfileItemsAsync(link.Id, tracked: false, cancellationToken);
        return Ok(ProfileView(patientId, items, link.FamilyHistory, link.ProfileNotes));
    }

    /// <summary>
    /// D7: replaces the whole medical profile. Items that stay keep their row (and who added them); removed
    /// items are deleted, since the lists are a current summary, not records (the audit row counts them).
    /// </summary>
    [HttpPost("updateMedicalProfile")]
    [Clinic(ClinicPermissions.ClinicalEditProfile)]
    public async Task<IActionResult> UpdateMedicalProfile(UpdateMedicalProfileRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = request.PatientId!.Value;
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var link = await PatientLinks.LockAsync(db, caller.DoctorId, patientId, cancellationToken);
        if (link is null)
        {
            return this.NotFoundProblem();
        }

        var now = Now;
        var existing = await LoadProfileItemsAsync(link.Id, tracked: true, cancellationToken);
        var wanted = new Dictionary<string, List<string>>
        {
            [ProfileKinds.Allergy] = CleanList(request.Allergies),
            [ProfileKinds.ChronicDisease] = CleanList(request.ChronicDiseases),
            [ProfileKinds.CurrentMedication] = CleanList(request.CurrentMedications),
            [ProfileKinds.Surgery] = CleanList(request.Surgeries),
        };
        var changed = new List<string>();
        int added = 0, removed = 0;
        foreach (var (kind, texts) in wanted)
        {
            var current = existing.Where(i => i.Kind == kind).ToList();
            if (current.Select(i => i.Text).SequenceEqual(texts))
            {
                continue;
            }

            changed.Add(ListName(kind));
            var unused = current.ToList();
            for (var order = 0; order < texts.Count; order++)
            {
                var item = unused.FirstOrDefault(i => i.Text == texts[order]);
                if (item is null)
                {
                    db.PatientMedicalProfileItems.Add(new PatientMedicalProfileItem
                    {
                        Id = Guid.NewGuid(), LinkId = link.Id, Kind = kind, Text = texts[order], SortOrder = order,
                        CreatedBy = caller.UserId, CreatedAt = now,
                    });
                    added++;
                }
                else
                {
                    item.SortOrder = order;
                    unused.Remove(item);
                }
            }

            // BR-P8: soft delete; the query filter hides them from now on.
            foreach (var item in unused)
            {
                item.DeletedAt = now;
                item.DeletedBy = caller.UserId;
            }

            removed += unused.Count;
        }

        var familyHistory = Text.TrimToNull(request.FamilyHistory);
        var notes = Text.TrimToNull(request.Notes);
        if (familyHistory != link.FamilyHistory)
        {
            changed.Add("familyHistory");
            link.FamilyHistory = familyHistory;
        }

        if (notes != link.ProfileNotes)
        {
            changed.Add("notes");
            link.ProfileNotes = notes;
        }

        if (changed.Count > 0)
        {
            link.UpdatedAt = now;
            auditor.AddClinic(
                caller, AuditActions.PatientMedicalProfileUpdated, AuditTargets.Patient, patientId,
                new { fields = changed, added, removed }, patientId);
            await db.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        var items = await LoadProfileItemsAsync(link.Id, tracked: false, cancellationToken);
        return Ok(ProfileView(patientId, items, link.FamilyHistory, link.ProfileNotes));
    }

    /// <summary>D4 / AS2 (<c>getPatientsRegister</c>). Any clinic caller: the patient list is doctor-wide (BR-AS13).</summary>
    [HttpGet("register")]
    public async Task<IActionResult> Register([FromQuery] PatientsRegisterQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (await RefuseRegisterQueryAsync(caller, query, cancellationToken) is { } refused)
        {
            return refused;
        }

        return Ok(await PatientsRegister.PageAsync(db, caller, query, Today, cancellationToken));
    }

    /// <summary>
    /// D4 [S] "Export CSV": every patient the register's filters and sort select (paging is ignored), as a CSV
    /// file with Arabic (<c>lang=ar</c>, the default) or English (<c>lang=en</c>) headers and values. Money and
    /// clinical columns follow the same permissions as the rows. Doctor only, because it is the whole patient
    /// list with phone numbers; audited as <c>patientsExported</c>. 400 <c>EXPORT_TOO_LARGE</c> over 20,000 rows.
    /// </summary>
    [HttpGet("register/export")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> ExportRegister(
        [FromQuery] PatientsRegisterQuery query, [FromQuery] string? lang, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (await RefuseRegisterQueryAsync(caller, query, cancellationToken) is { } refused)
        {
            return refused;
        }

        var arabic = lang != "en";
        if (await PatientsRegisterCsv.BuildAsync(db, caller, query, Today, arabic, cancellationToken) is not { } file)
        {
            return this.Problem(StatusCodes.Status400BadRequest, ErrorCodes.ExportTooLarge, "Too many patients for one file; narrow the filters.")
                .WithFields(("maxRows", PatientsRegisterCsv.MaxRows));
        }

        auditor.AddClinic(caller, AuditActions.PatientsExported, AuditTargets.Patient, null, new
        {
            rows = file.Rows,
            lang = arabic ? "ar" : "en",
            filters = new
            {
                search = Text.TrimToNull(query.Search) is not null,
                query.LastVisit, query.BranchId, query.MinVisits, query.MaxVisits, query.NewThisMonth,
                query.HasUpcomingBooking, query.HasNoShows, query.Archived, query.HasChronicDisease,
            },
        });
        await db.SaveChangesAsync(cancellationToken);

        Response.Headers.CacheControl = "no-store";
        return File(file.Content, "text/csv; charset=utf-8", PatientsRegisterCsv.FileName(Today));
    }

    /// <summary>
    /// The account's login can't change while it is being deleted (409 <c>ACCOUNT_DELETION_SCHEDULED</c>) or after it was
    /// erased (409 <c>ACCOUNT_DELETED</c>, spec 6.17). Null: allowed.
    /// </summary>
    private async Task<IActionResult?> DeletionRefusalAsync(Guid userId, CancellationToken cancellationToken)
    {
        var status = await db.Users.Where(u => u.Id == userId).Select(u => u.Status).SingleAsync(cancellationToken);
        return status switch
        {
            AccountStatuses.Deleted => this.ConflictProblem(ErrorCodes.AccountDeleted, "This patient's account was deleted."),
            AccountStatuses.PendingDeletion => this.ConflictProblem(
                ErrorCodes.AccountDeletionScheduled, "This patient's account is scheduled for deletion."),
            _ => null,
        };
    }

    /// <summary>The register's permission and branch checks, shared by the list and the export (null: allowed).</summary>
    private async Task<IActionResult?> RefuseRegisterQueryAsync(ClinicCaller caller, PatientsRegisterQuery query, CancellationToken cancellationToken)
    {
        var clinicalFilter = query.HasChronicDisease == true || Text.TrimToNull(query.ChronicDisease) is not null
            || query.Sort == RegisterSort.Allergies;
        if (clinicalFilter && !caller.Has(ClinicPermissions.ClinicalView))
        {
            return this.PermissionDenied(ClinicPermissions.ClinicalView);
        }

        if (query.Sort == RegisterSort.TotalPaid && !caller.Has(ClinicPermissions.RevenueView))
        {
            return this.PermissionDenied(ClinicPermissions.RevenueView);
        }

        if (query.Sort == RegisterSort.UnreadChat && !caller.Has(ClinicPermissions.Chat))
        {
            return this.PermissionDenied(ClinicPermissions.Chat);
        }

        if (query.BranchId is { } branchId
            && !await db.Branches.AnyAsync(b => b.Id == branchId && b.DoctorId == caller.DoctorId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        return null;
    }

    /// <summary>
    /// Sets the identity fields from the request (names tidied). With <paramref name="details"/>, also the
    /// optional details, cleared when empty (BR-P3: only the creating clinic has them).
    /// </summary>
    private static void ApplyIdentity(Patient patient, IPatientIdentity input, DateOnly today, bool details)
    {
        patient.FullName = Text.CollapseSpaces(input.FullName!);
        patient.Gender = input.Gender!;
        if (input.DateOfBirth is { } dateOfBirth)
        {
            patient.DateOfBirth = dateOfBirth;
            patient.DateOfBirthEstimated = false;
        }
        else if (!(patient.DateOfBirthEstimated && patient.DateOfBirth != default
                   && PatientAge.Years(patient.DateOfBirth, today) == input.AgeYears))
        {
            // Keep an estimated date while the age typed is still the age it gives, so saving the form again
            // doesn't move the date of birth every day.
            patient.DateOfBirth = PatientAge.EstimatedDateOfBirth(input.AgeYears!.Value, today);
            patient.DateOfBirthEstimated = true;
        }

        if (!details)
        {
            return;
        }

        patient.NationalId = Patients.NationalId.Normalize(input.NationalId);
        patient.Address = Text.TrimToNull(input.Address);
        patient.BloodType = Text.TrimToNull(input.BloodType);
        patient.EmergencyContactName = Text.TrimToNull(input.EmergencyContactName) is { } contact ? Text.CollapseSpaces(contact) : null;
        patient.EmergencyContactPhone = EgyptianPhone.Normalize(Text.TrimToNull(input.EmergencyContactPhone));
    }

    private static Dictionary<string, object?> IdentityFields(Patient p) => new()
    {
        ["fullName"] = p.FullName,
        ["gender"] = p.Gender,
        ["dateOfBirth"] = p.DateOfBirth,
        ["dateOfBirthEstimated"] = p.DateOfBirthEstimated,
        ["nationalId"] = p.NationalId,
        ["address"] = p.Address,
        ["bloodType"] = p.BloodType,
        ["emergencyContactName"] = p.EmergencyContactName,
        ["emergencyContactPhone"] = p.EmergencyContactPhone,
    };

    private async Task<List<PatientMedicalProfileItem>> LoadProfileItemsAsync(Guid linkId, bool tracked, CancellationToken cancellationToken)
    {
        var items = db.PatientMedicalProfileItems.Where(i => i.LinkId == linkId);
        return await (tracked ? items : items.AsNoTracking())
            .OrderBy(i => i.SortOrder).ThenBy(i => i.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    private static MedicalProfileView ProfileView(
        Guid patientId, IReadOnlyList<PatientMedicalProfileItem> items, string? familyHistory, string? notes)
    {
        List<ProfileItemView> Of(string kind) =>
            items.Where(i => i.Kind == kind).OrderBy(i => i.SortOrder).Select(i => new ProfileItemView(i.Id, i.Text)).ToList();

        var allergies = Of(ProfileKinds.Allergy);
        return new MedicalProfileView(
            patientId, allergies.Count > 0, allergies, Of(ProfileKinds.ChronicDisease), Of(ProfileKinds.CurrentMedication),
            Of(ProfileKinds.Surgery), familyHistory, notes);
    }

    /// <summary>Trimmed, single-spaced, without empty items or repeats (ignoring case), in the order sent.</summary>
    private static List<string> CleanList(IReadOnlyList<string?>? items) =>
        (items ?? [])
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => Text.CollapseSpaces(item!))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

    private static string ListName(string kind) => kind switch
    {
        ProfileKinds.Allergy => "allergies",
        ProfileKinds.ChronicDisease => "chronicDiseases",
        ProfileKinds.CurrentMedication => "currentMedications",
        _ => "surgeries",
    };
}
