using El3yada.Api.Auth;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Firebase;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Features.Appointments;

/// <summary>P15–P17: the patient books with linked doctors, within each clinic's rules.</summary>
[ApiController]
[Route("api/patient")]
[Authorize(Policy = Policies.Patient)]
[Produces("application/json")]
public sealed class PatientAppointmentsController(AppointmentService appointments) : ControllerBase
{
    [HttpGet("doctors/{doctorId:guid}/booking-options", Name = "getBookingOptions")]
    public async Task<BookingOptionsDto> Options(Guid doctorId, CancellationToken ct) =>
        await appointments.BookingOptionsAsync(await appointments.PatientActorAsync(ct), doctorId, ct);

    /// <summary><c>getAvailability</c> for patients: every self-booking limit applied (BR-AP1, BR-AP7).</summary>
    [HttpGet("availability", Name = "getPatientAvailability")]
    public async Task<AvailabilityDto> Availability([FromQuery] AvailabilityQuery query, CancellationToken ct) =>
        await appointments.AvailabilityAsync(await appointments.PatientActorAsync(ct), query, ct);

    /// <summary>P16. <c>tab</c>: upcoming (default), past or cancelled.</summary>
    [HttpGet("appointments", Name = "getMyAppointments")]
    public async Task<IReadOnlyList<AppointmentDto>> List([FromQuery] string? tab, CancellationToken ct) =>
        await appointments.PatientListAsync(await appointments.PatientActorAsync(ct), tab ?? "upcoming", ct);

    [HttpGet("appointments/{id:guid}", Name = "getMyAppointment")]
    public async Task<AppointmentDto> Get(Guid id, CancellationToken ct) =>
        await appointments.GetAsync(await appointments.PatientActorAsync(ct), id, ct);

    /// <summary><c>createAppointment</c> (P15). Errors use the 6.12.6 codes.</summary>
    [HttpPost("appointments", Name = "createMyAppointment")]
    public async Task<AppointmentDto> Create(CreateAppointmentRequest request, CancellationToken ct) =>
        await appointments.CreateAsync(await appointments.PatientActorAsync(ct), request, ct);

    [HttpPost("appointments/{id:guid}/reschedule", Name = "rescheduleMyAppointment")]
    public async Task<AppointmentDto> Reschedule(Guid id, RescheduleRequest request, CancellationToken ct) =>
        await appointments.RescheduleAsync(await appointments.PatientActorAsync(ct), id, request, ct);

    [HttpPost("appointments/{id:guid}/cancel", Name = "cancelMyAppointment")]
    public async Task<AppointmentDto> Cancel(Guid id, ReasonRequest request, CancellationToken ct) =>
        await appointments.CancelAsync(await appointments.PatientActorAsync(ct), id, request.Reason, ct);
}

/// <summary>
/// D29–D34, AS13–AS17: bookings, the live board and the schedule. Assistants need
/// <c>appointmentsView</c> to read, <c>appointmentsManage</c> to act and <c>scheduleManage</c> for the
/// schedule, always limited to their branches (BR-AP20).
/// </summary>
[ApiController]
[Route("api/staff")]
[Authorize(Policy = Policies.Staff)]
[Produces("application/json")]
public sealed class StaffAppointmentsController(
    AppointmentService appointments,
    BoardActionsService board,
    ScheduleService schedule,
    AppointmentSearchService search) : ControllerBase
{
    private Task<BookingActor> View(CancellationToken ct) => appointments.StaffActorAsync(StaffPermission.AppointmentsView, ct);
    private Task<BookingActor> Manage(CancellationToken ct) => appointments.StaffActorAsync(StaffPermission.AppointmentsManage, ct);

    // ---- Branches and schedule ---------------------------------------------------------------

    /// <summary>The caller's branches, for the current-branch picker (BR-BR3).</summary>
    [HttpGet("branches", Name = "getStaffBranches")]
    public Task<IReadOnlyList<StaffBranchDto>> Branches(CancellationToken ct) => schedule.BranchesAsync(ct);

    [HttpGet("branches/{branchId:guid}/schedule", Name = "getBranchSchedule")]
    public Task<ScheduleDto> GetSchedule(Guid branchId, CancellationToken ct) => schedule.GetAsync(branchId, ct);

    /// <summary><c>updateBranchSchedule</c>: send <c>dryRun = true</c> first to list the affected bookings (BR-AP12).</summary>
    [HttpPut("branches/{branchId:guid}/schedule", Name = "updateBranchSchedule")]
    public Task<UpdateScheduleResult> UpdateSchedule(Guid branchId, UpdateScheduleRequest request, CancellationToken ct) =>
        schedule.UpdateAsync(branchId, request, ct);

    [HttpGet("availability", Name = "getStaffAvailability")]
    public async Task<AvailabilityDto> Availability([FromQuery] AvailabilityQuery query, CancellationToken ct) =>
        await appointments.AvailabilityAsync(await View(ct), query, ct);

    // ---- Bookings -----------------------------------------------------------------------------

    [HttpGet("appointments", Name = "searchAppointments")]
    public async Task<SearchResultDto> Search([FromQuery] SearchAppointmentsQuery query, CancellationToken ct) =>
        await search.SearchAsync(await View(ct), query, ct);

    [HttpGet("appointments/{id:guid}", Name = "getAppointment")]
    public async Task<AppointmentDto> Get(Guid id, CancellationToken ct) => await appointments.GetAsync(await View(ct), id, ct);

    [HttpPost("appointments", Name = "createAppointment")]
    public async Task<AppointmentDto> Create(CreateAppointmentRequest request, CancellationToken ct) =>
        await appointments.CreateAsync(await Manage(ct), request, ct);

    [HttpPost("appointments/{id:guid}/reschedule", Name = "rescheduleAppointment")]
    public async Task<AppointmentDto> Reschedule(Guid id, RescheduleRequest request, CancellationToken ct) =>
        await appointments.RescheduleAsync(await Manage(ct), id, request, ct);

    [HttpPost("appointments/{id:guid}/cancel", Name = "cancelAppointment")]
    public async Task<AppointmentDto> Cancel(Guid id, ReasonRequest request, CancellationToken ct) =>
        await appointments.CancelAsync(await Manage(ct), id, request.Reason, ct);

    [HttpPost("appointments/{id:guid}/confirm", Name = "confirmAppointment")]
    public async Task<AppointmentDto> Confirm(Guid id, CancellationToken ct) => await appointments.ConfirmAsync(await Manage(ct), id, ct);

    [HttpPost("appointments/{id:guid}/reject", Name = "rejectAppointment")]
    public async Task<AppointmentDto> Reject(Guid id, ReasonRequest request, CancellationToken ct) =>
        await appointments.RejectAsync(await Manage(ct), id, request.Reason, ct);

    [HttpPost("appointments/{id:guid}/check-in", Name = "checkInAppointment")]
    public async Task<AppointmentDto> CheckIn(Guid id, CancellationToken ct) => await board.CheckInAsync(await Manage(ct), id, ct);

    [HttpPost("appointments/{id:guid}/no-show", Name = "markNoShow")]
    public async Task<AppointmentDto> NoShow(Guid id, CancellationToken ct) => await board.MarkNoShowAsync(await Manage(ct), id, ct);

    [HttpPost("appointments/{id:guid}/undo-no-show", Name = "undoNoShow")]
    public async Task<AppointmentDto> UndoNoShow(Guid id, CancellationToken ct) => await board.UndoNoShowAsync(await Manage(ct), id, ct);

    [HttpPost("appointments/{id:guid}/left-without-seen", Name = "markLeftWithoutSeen")]
    public async Task<AppointmentDto> LeftWithoutSeen(Guid id, ReasonRequest request, CancellationToken ct) =>
        await board.MarkLeftWithoutSeenAsync(await Manage(ct), id, request.Reason, ct);

    [HttpPost("appointments/{id:guid}/call-in", Name = "callIn")]
    public async Task<AppointmentDto> CallIn(Guid id, CancellationToken ct) => await board.CallInAsync(await Manage(ct), id, ct);

    [HttpPost("appointments/{id:guid}/send-back", Name = "sendBackToWaiting")]
    public async Task<AppointmentDto> SendBack(Guid id, CancellationToken ct) => await board.SendBackAsync(await Manage(ct), id, ct);

    [HttpPost("appointments/{id:guid}/priority", Name = "movePriority")]
    public async Task<AppointmentDto> Priority(Guid id, ReasonRequest request, CancellationToken ct) =>
        await board.MovePriorityAsync(await Manage(ct), id, request.Reason, ct);

    [HttpPost("appointments/{id:guid}/convert-guest", Name = "convertGuest")]
    public async Task<AppointmentDto> ConvertGuest(Guid id, ConvertGuestRequest request, CancellationToken ct) =>
        await board.ConvertGuestAsync(await Manage(ct), id, request.PatientId, ct);

    [HttpPut("patients/{patientId:guid}/self-booking", Name = "setSelfBooking")]
    public async Task<IActionResult> SetSelfBooking(Guid patientId, SetSelfBookingRequest request, CancellationToken ct)
    {
        await board.SetSelfBookingAsync(await Manage(ct), patientId, request, ct);
        return NoContent();
    }

    // ---- Live board (D34, AS1, AS16) ----------------------------------------------------------

    /// <summary>The board from SQL Server: first load, and the 15-second fallback when Firestore is off (spec 9.6).</summary>
    [HttpGet("board", Name = "getBoard")]
    public async Task<BoardSnapshot> Board([FromQuery] Guid branchId, [FromQuery] DateOnly? date, CancellationToken ct) =>
        await board.GetBoardAsync(await View(ct), branchId, date, ct);

    [HttpGet("board/{appointmentId:guid}/summary", Name = "getBoardPatientSummary")]
    public async Task<BoardPatientSummaryDto> Summary(Guid appointmentId, CancellationToken ct) =>
        await board.PatientSummaryAsync(await View(ct), appointmentId, ct);

    [HttpPost("board/walk-in", Name = "addWalkIn")]
    public async Task<AppointmentDto> WalkIn(WalkInRequest request, CancellationToken ct) => await board.AddWalkInAsync(await Manage(ct), request, ct);

    [HttpPost("board/call-next", Name = "callNext")]
    public async Task<ActionResult<AppointmentDto>> CallNext([FromQuery] Guid branchId, CancellationToken ct) =>
        await board.CallNextAsync(await Manage(ct), branchId, ct) is { } next ? next : NoContent();

    [HttpPost("board/cancel-rest-of-day", Name = "cancelRestOfDay")]
    public async Task<object> CancelRestOfDay(BranchDayRequest request, CancellationToken ct) =>
        new { cancelled = await board.CancelRestOfDayAsync(await Manage(ct), request, ct) };

    [HttpPost("board/delay", Name = "sendDelayNotice")]
    public async Task<object> Delay(DelayRequest request, CancellationToken ct) =>
        new { notified = await board.SendDelayNoticeAsync(await Manage(ct), request, ct) };
}
