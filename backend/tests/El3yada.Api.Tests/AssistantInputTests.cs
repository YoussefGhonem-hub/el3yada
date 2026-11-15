using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;

namespace El3yada.Api.Tests;

/// <summary>Permissions sent by createAssistant / updateAssistant become columns with their dependencies (spec 6.10).</summary>
public sealed class AssistantPermissionInputTests
{
    [Fact]
    public void Switched_on_keys_get_their_dependencies_and_switched_off_keys_are_ignored()
    {
        var keys = AssistantRules.Keys(new Dictionary<string, bool>
        {
            [ClinicPermissions.ScheduleManage] = true,
            [ClinicPermissions.PrescriptionsDraft] = true,
            [ClinicPermissions.Chat] = false,
        });

        Assert.Equal(
            new HashSet<string>
            {
                ClinicPermissions.ScheduleManage, ClinicPermissions.AppointmentsManage, ClinicPermissions.AppointmentsView,
                ClinicPermissions.PrescriptionsDraft, ClinicPermissions.ClinicalView,
            },
            keys);
        Assert.Equal(AssistantPresets.Custom, AssistantPresets.Match(keys));
    }

    [Fact]
    public void A_preset_map_matches_its_preset() =>
        Assert.Equal(
            AssistantPresets.OfficeManager,
            AssistantPresets.Match(AssistantRules.Keys(ClinicPermissions.ToMap(AssistantPresets.Permissions[AssistantPresets.OfficeManager]))));

    [Fact]
    public void Unknown_keys_are_refused()
    {
        var validator = new CreateAssistantRequestValidator();
        var result = validator.Validate(new CreateAssistantRequest(
            "سارة محمود", "01012345678", true, null, new Dictionary<string, bool> { ["deleteEverything"] = true }));
        Assert.Contains(result.Errors, e => e.PropertyName == "Permissions" && e.ErrorCode == ErrorCodes.InvalidValue);
    }

    [Fact]
    public void Branches_are_required_unless_all_branches()
    {
        var validator = new CreateAssistantRequestValidator();
        var permissions = new Dictionary<string, bool>();
        Assert.Contains(validator.Validate(new CreateAssistantRequest("سارة محمود", "01012345678", false, null, permissions)).Errors,
            e => e.PropertyName == "BranchIds" && e.ErrorCode == ErrorCodes.Required);
        Assert.True(validator.Validate(new CreateAssistantRequest("سارة محمود", "01012345678", true, null, permissions)).IsValid);
    }
}
