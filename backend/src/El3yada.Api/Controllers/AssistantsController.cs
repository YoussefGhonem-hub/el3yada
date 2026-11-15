using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// The doctor's assistants (D25, D26; spec 6.10, 9.1 <c>createAssistant</c>, <c>updateAssistant</c>,
/// <c>resetAssistantPassword</c>, <c>setAssistantStatus</c>). Doctor only, whatever the permissions (BR-AS5), and
/// allowed while suspended. Permissions are read from the database on each of the assistant's requests
/// (BR-AS4), so a change here applies on their next request.
/// </summary>
[ApiController]
[Route("api/assistants")]
[Clinic(DoctorOnly = true)]
public sealed class AssistantsController(
    AppDbContext db, Passwords passwords, SessionService sessions, Auditor auditor, AccountStateCache stateCache,
    IdentifierThrottle throttle, TimeProvider time) : ControllerBase
{
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>D25, oldest first, removed ones last (and only with <c>includeRemoved=true</c>).</summary>
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] AssistantListQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var rows = await db.Assistants.AsNoTracking()
            .Where(a => a.DoctorId == caller.DoctorId && (query.IncludeRemoved || a.Status != AssistantStatuses.Removed))
            .OrderBy(a => a.Status == AssistantStatuses.Removed).ThenBy(a => a.CreatedAt)
            .Select(a => new { Assistant = a, Branches = a.Branches.ToList(), a.User.MustChangePassword })
            .ToListAsync(cancellationToken);
        var count = await CountTowardLimitAsync(caller.DoctorId, cancellationToken);
        var limit = await LimitAsync(cancellationToken);
        return Ok(new AssistantListView(
            rows.Select(r =>
            {
                r.Assistant.Branches = r.Branches;
                return AssistantView.Of(r.Assistant, r.MustChangePassword);
            }).ToList(),
            count, limit, count < limit));
    }

    /// <summary>D26 edit form.</summary>
    [HttpGet("{assistantId:guid}")]
    public async Task<IActionResult> Get(Guid assistantId, CancellationToken cancellationToken)
    {
        var view = await LoadViewAsync(HttpContext.Clinic(), assistantId, cancellationToken);
        return view is null ? this.NotFoundProblem() : Ok(view);
    }

    /// <summary>
    /// Creates the assistant's account (role assistant, <c>mustChangePassword</c>) with an 8-character temporary
    /// password, returned once (BR-AS2). The number may already be a patient account (A3), but not an
    /// assistant of any doctor (BR-AS3). Up to maxAssistantsPerDoctor active and disabled assistants (BR-AS1).
    /// </summary>
    [HttpPost("createAssistant")]
    public async Task<IActionResult> CreateAssistant(CreateAssistantRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var allBranches = request.AllBranches == true;
        var branches = allBranches ? [] : await LoadBranchesAsync(caller.DoctorId, request.BranchIds!, cancellationToken);
        if (branches is null)
        {
            return InvalidBranches();
        }

        var phone = EgyptianMobile.Normalize(request.Phone)!;
        var keys = AssistantRules.Keys(request.Permissions!);
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, caller.DoctorId, cancellationToken);
        if (await CountTowardLimitAsync(caller.DoctorId, cancellationToken) >= await LimitAsync(cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.AssistantLimitReached, "The clinic has the most assistants allowed.");
        }

        if (await PhoneTakenAsync(phone, null, cancellationToken))
        {
            return PhoneTaken();
        }

        var now = Now;
        var temporaryPassword = Passwords.GenerateTemporary();
        var name = Text.CollapseSpaces(request.FullName!);
        var user = new User
        {
            Id = Guid.NewGuid(),
            Role = Roles.Assistant,
            Status = AccountStatuses.Active,
            DisplayName = name,
            Phone = phone,
            SecurityStamp = Guid.NewGuid(),
            MustChangePassword = true,
            CreatedAt = now,
            UpdatedAt = now,
        };
        user.PasswordHash = passwords.Hash(user, temporaryPassword);
        var assistant = new Assistant
        {
            UserId = user.Id,
            DoctorId = caller.DoctorId,
            FullName = name,
            Phone = phone,
            Preset = AssistantPresets.Match(keys),
            AllBranches = allBranches,
            Status = AssistantStatuses.Active,
            CreatedBy = caller.UserId,
            CreatedAt = now,
            UpdatedAt = now,
        };
        ClinicPermissions.Apply(assistant, keys);
        foreach (var branch in branches)
        {
            assistant.Branches.Add(branch);
        }

        db.Users.Add(user);
        db.Assistants.Add(assistant);
        auditor.AddClinic(
            caller, AuditActions.AssistantCreated, AuditTargets.Assistant, user.Id,
            new { preset = assistant.Preset, allBranches, branchIds = branches.Select(b => b.Id), permissions = Sorted(keys) });
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation("UQ_Assistants_Phone"))
        {
            return PhoneTaken();
        }

        await transaction.CommitAsync(cancellationToken);
        Response.Headers.CacheControl = "no-store";
        return StatusCode(StatusCodes.Status201Created, new AssistantWithPasswordView(AssistantView.Of(assistant, true), temporaryPassword));
    }

    /// <summary>
    /// Changes the name, mobile (Users.Phone too, so they sign in with the new number), branches and permissions
    /// (dependencies switched on, the preset recomputed). A permission change is audited as
    /// <c>assistantPermissionsChanged</c> (D27 "permission changed").
    /// </summary>
    [HttpPost("updateAssistant")]
    public async Task<IActionResult> UpdateAssistant(UpdateAssistantRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var assistant = await db.Assistants.Include(a => a.User).Include(a => a.Branches)
            .SingleOrDefaultAsync(a => a.UserId == request.AssistantId && a.DoctorId == caller.DoctorId, cancellationToken);
        if (assistant is null)
        {
            return this.NotFoundProblem();
        }

        if (assistant.Status == AssistantStatuses.Removed)
        {
            return Removed();
        }

        var fields = new List<string>();
        if (request.FullName is not null && Text.CollapseSpaces(request.FullName) is var name && name != assistant.FullName)
        {
            assistant.FullName = name;
            assistant.User.DisplayName = name;
            fields.Add("fullName");
        }

        if (request.Phone is not null && EgyptianMobile.Normalize(request.Phone) is { } phone && phone != assistant.Phone)
        {
            if (await PhoneTakenAsync(phone, assistant.UserId, cancellationToken))
            {
                return PhoneTaken();
            }

            assistant.Phone = phone;
            assistant.User.Phone = phone;
            fields.Add("phone");
        }

        if (request.ChangesBranches)
        {
            var allBranches = request.AllBranches ?? (request.BranchIds is null && assistant.AllBranches);
            var branches = allBranches ? [] : await LoadBranchesAsync(caller.DoctorId, request.BranchIds!, cancellationToken);
            if (branches is null)
            {
                return InvalidBranches();
            }

            if (allBranches != assistant.AllBranches || !assistant.Branches.Select(b => b.Id).ToHashSet().SetEquals(branches.Select(b => b.Id)))
            {
                assistant.AllBranches = allBranches;
                assistant.Branches.Clear();
                foreach (var branch in branches)
                {
                    assistant.Branches.Add(branch);
                }

                fields.Add("branches");
            }
        }

        var permissionsChanged = false;
        if (request.Permissions is not null)
        {
            var before = ClinicPermissions.Of(assistant);
            var after = AssistantRules.Keys(request.Permissions);
            if (!before.SetEquals(after))
            {
                var presetBefore = assistant.Preset;
                ClinicPermissions.Apply(assistant, after);
                assistant.Preset = AssistantPresets.Match(after);
                permissionsChanged = true;
                auditor.AddClinic(
                    caller, AuditActions.AssistantPermissionsChanged, AuditTargets.Assistant, assistant.UserId,
                    new
                    {
                        added = Sorted(after.Except(before)),
                        removed = Sorted(before.Except(after)),
                        presetBefore,
                        presetAfter = assistant.Preset,
                    });
            }
        }

        if (fields.Count == 0 && !permissionsChanged)
        {
            return Ok(AssistantView.Of(assistant, assistant.User.MustChangePassword));
        }

        var now = Now;
        assistant.UpdatedAt = now;
        assistant.User.UpdatedAt = now;
        if (fields.Count > 0)
        {
            auditor.AddClinic(caller, AuditActions.AssistantUpdated, AuditTargets.Assistant, assistant.UserId, new { fields });
        }

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation("UQ_Assistants_Phone"))
        {
            return PhoneTaken();
        }

        stateCache.Invalidate(assistant.UserId);
        return Ok(AssistantView.Of(assistant, assistant.User.MustChangePassword));
    }

    /// <summary>
    /// A8 forgot password for an assistant ends here (BR-AS11): a new temporary password (shown once),
    /// <c>mustChangePassword</c>, and every device signed out (new security stamp, refresh tokens revoked).
    /// </summary>
    [HttpPost("resetAssistantPassword")]
    public async Task<IActionResult> ResetAssistantPassword(AssistantIdRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var assistant = await db.Assistants.Include(a => a.User).Include(a => a.Branches)
            .SingleOrDefaultAsync(a => a.UserId == request.AssistantId && a.DoctorId == caller.DoctorId, cancellationToken);
        if (assistant is null)
        {
            return this.NotFoundProblem();
        }

        if (assistant.Status == AssistantStatuses.Removed)
        {
            return Removed();
        }

        var user = assistant.User;
        var temporaryPassword = Passwords.GenerateTemporary();
        user.PasswordHash = passwords.Hash(user, temporaryPassword);
        user.MustChangePassword = true;
        user.AccessFailedCount = 0;
        user.LockoutEndAt = null;
        auditor.AddClinic(caller, AuditActions.AssistantPasswordReset, AuditTargets.Assistant, assistant.UserId);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await sessions.SignOutEverywhereAsync(user, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        stateCache.Invalidate(user.Id);
        throttle.ClearLoginBlock(user.Phone!);

        Response.Headers.CacheControl = "no-store";
        return Ok(new AssistantWithPasswordView(AssistantView.Of(assistant, true), temporaryPassword));
    }

    /// <summary>
    /// Enable, disable or remove (BR-AS8). Disabling and removing revoke every refresh token and the device push
    /// tokens at once; the next request with a current access token answers 403 <c>ACCOUNT_DISABLED</c>
    /// (AC-19). Removing is soft and final: the history stays in D27 and the number can be used again.
    /// </summary>
    [HttpPost("setAssistantStatus")]
    public async Task<IActionResult> SetAssistantStatus(SetAssistantStatusRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var assistant = await db.Assistants.Include(a => a.User).Include(a => a.Branches)
            .SingleOrDefaultAsync(a => a.UserId == request.AssistantId && a.DoctorId == caller.DoctorId, cancellationToken);
        if (assistant is null)
        {
            return this.NotFoundProblem();
        }

        var target = request.Status!;
        if (assistant.Status == target)
        {
            return Ok(AssistantView.Of(assistant, assistant.User.MustChangePassword));
        }

        if (assistant.Status == AssistantStatuses.Removed)
        {
            return Removed();
        }

        var now = Now;
        assistant.Status = target;
        assistant.UpdatedAt = now;
        if (target == AssistantStatuses.Removed)
        {
            assistant.RemovedAt = now;
        }

        var action = target switch
        {
            AssistantStatuses.Active => AuditActions.AssistantEnabled,
            AssistantStatuses.Disabled => AuditActions.AssistantDisabled,
            _ => AuditActions.AssistantRemoved,
        };
        auditor.AddClinic(caller, action, AuditTargets.Assistant, assistant.UserId);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        if (target != AssistantStatuses.Active)
        {
            // The security stamp stays, so their next request says ACCOUNT_DISABLED (A10) rather than SESSION_REVOKED.
            await sessions.RevokeAllAsync(assistant.UserId, cancellationToken);
            await db.UserDevices.Where(d => d.UserId == assistant.UserId).ExecuteDeleteAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        stateCache.Invalidate(assistant.UserId);
        return Ok(AssistantView.Of(assistant, assistant.User.MustChangePassword));
    }

    private async Task<AssistantView?> LoadViewAsync(ClinicCaller caller, Guid assistantId, CancellationToken cancellationToken)
    {
        var row = await db.Assistants.AsNoTracking()
            .Where(a => a.UserId == assistantId && a.DoctorId == caller.DoctorId)
            .Select(a => new { Assistant = a, Branches = a.Branches.ToList(), a.User.MustChangePassword })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null)
        {
            return null;
        }

        row.Assistant.Branches = row.Branches;
        return AssistantView.Of(row.Assistant, row.MustChangePassword);
    }

    /// <summary>The doctor's non-archived branches with these IDs, or null when any ID is not one of them.</summary>
    private async Task<List<Branch>?> LoadBranchesAsync(Guid doctorId, List<Guid> ids, CancellationToken cancellationToken)
    {
        var branches = await db.Branches
            .Where(b => ids.Contains(b.Id) && b.DoctorId == doctorId && b.Status != BranchStatuses.Archived)
            .ToListAsync(cancellationToken);
        return branches.Count == ids.Count ? branches : null;
    }

    /// <summary>Active and disabled assistants count toward the limit; removed ones don't.</summary>
    private Task<int> CountTowardLimitAsync(Guid doctorId, CancellationToken cancellationToken) =>
        db.Assistants.CountAsync(a => a.DoctorId == doctorId && a.Status != AssistantStatuses.Removed, cancellationToken);

    private Task<int> LimitAsync(CancellationToken cancellationToken) =>
        db.AppSettings.AsNoTracking().Select(s => s.MaxAssistantsPerDoctor).SingleAsync(cancellationToken);

    /// <summary>BR-AS3: one number is an assistant of one doctor at a time (UQ_Assistants_Phone, active and disabled).</summary>
    private Task<bool> PhoneTakenAsync(string phone, Guid? except, CancellationToken cancellationToken) =>
        db.Assistants.AnyAsync(
            a => a.Phone == phone && a.Status != AssistantStatuses.Removed && a.UserId != except, cancellationToken);

    private static string[] Sorted(IEnumerable<string> keys) =>
        ClinicPermissions.All.Where(keys.Contains).ToArray();

    private IActionResult InvalidBranches() =>
        ValidationProblems.Field(HttpContext, "branchIds", ErrorCodes.InvalidBranch, "Choose the clinic's branches that are not archived.");

    private ObjectResult PhoneTaken() =>
        this.ConflictProblem(ErrorCodes.AssistantPhoneTaken, "This number is already an assistant's.");

    private ObjectResult Removed() =>
        this.ConflictProblem(ErrorCodes.AssistantRemoved, "This assistant was removed. Add them again as a new assistant.");
}
