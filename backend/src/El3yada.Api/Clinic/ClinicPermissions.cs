using El3yada.Data.Entities;

namespace El3yada.Api.Clinic;

/// <summary>
/// Assistant permission keys (spec 6.10). Each key is the JSON name the app uses and maps to one bool column
/// on Assistants. A doctor has every permission. Some things are never allowed to an assistant whatever the
/// permissions (BR-AS5): those endpoints are marked <c>DoctorOnly</c> on <see cref="ClinicAttribute"/>.
/// </summary>
public static class ClinicPermissions
{
    public const string PatientsManage = "patientsManage";
    public const string PatientsResetPassword = "patientsResetPassword";
    public const string SessionsCreate = "sessionsCreate";
    public const string SessionsDelete = "sessionsDelete";
    public const string ClinicalView = "clinicalView";
    public const string ClinicalEditProfile = "clinicalEditProfile";
    public const string FilesManage = "filesManage";
    public const string PrescriptionsPrint = "prescriptionsPrint";
    public const string PrescriptionsDraft = "prescriptionsDraft";
    public const string Chat = "chat";
    public const string BillingView = "billingView";
    public const string BillingPay = "billingPay";
    public const string AppointmentsView = "appointmentsView";
    public const string AppointmentsManage = "appointmentsManage";
    public const string ScheduleManage = "scheduleManage";
    public const string RevenueView = "revenueView";
    public const string PricesManage = "pricesManage";

    /// <summary>Every key, in the order of the spec's table (and of the D26 checklist).</summary>
    public static readonly IReadOnlyList<string> All =
    [
        PatientsManage, PatientsResetPassword, SessionsCreate, SessionsDelete, ClinicalView, ClinicalEditProfile,
        FilesManage, PrescriptionsPrint, PrescriptionsDraft, Chat, BillingView, BillingPay, AppointmentsView,
        AppointmentsManage, ScheduleManage, RevenueView, PricesManage,
    ];

    /// <summary>A permission that needs another (spec 6.10, "Dependencies"). Turning it on turns that one on.</summary>
    public static readonly IReadOnlyDictionary<string, string> Requires = new Dictionary<string, string>
    {
        [ClinicalEditProfile] = ClinicalView,
        [PrescriptionsDraft] = ClinicalView,
        [BillingPay] = BillingView,
        [AppointmentsManage] = AppointmentsView,
        [ScheduleManage] = AppointmentsManage,
    };

    public static bool IsKnown(string key) => Accessors.ContainsKey(key);

    /// <summary><paramref name="keys"/> plus everything they need, following chains (scheduleManage → appointmentsManage → appointmentsView).</summary>
    public static IReadOnlySet<string> WithDependencies(IEnumerable<string> keys)
    {
        var result = new HashSet<string>(keys.Where(IsKnown));
        var queue = new Queue<string>(result);
        while (queue.TryDequeue(out var key))
        {
            if (Requires.TryGetValue(key, out var needed) && result.Add(needed))
            {
                queue.Enqueue(needed);
            }
        }

        return result;
    }

    /// <summary>The permissions an assistant has now.</summary>
    public static IReadOnlySet<string> Of(Assistant assistant) =>
        Accessors.Where(pair => pair.Value.Get(assistant)).Select(pair => pair.Key).ToHashSet();

    /// <summary>Sets every permission column: on for the keys in <paramref name="keys"/>, off for the rest. Apply dependencies first.</summary>
    public static void Apply(Assistant assistant, IReadOnlySet<string> keys)
    {
        foreach (var (key, accessor) in Accessors)
        {
            accessor.Set(assistant, keys.Contains(key));
        }
    }

    /// <summary>Every key with its value, for answers (<c>{ "patientsManage": true, … }</c>).</summary>
    public static Dictionary<string, bool> ToMap(IReadOnlySet<string> keys) => All.ToDictionary(key => key, keys.Contains);

    private static readonly Dictionary<string, (Func<Assistant, bool> Get, Action<Assistant, bool> Set)> Accessors = new()
    {
        [PatientsManage] = (a => a.PatientsManage, (a, v) => a.PatientsManage = v),
        [PatientsResetPassword] = (a => a.PatientsResetPassword, (a, v) => a.PatientsResetPassword = v),
        [SessionsCreate] = (a => a.SessionsCreate, (a, v) => a.SessionsCreate = v),
        [SessionsDelete] = (a => a.SessionsDelete, (a, v) => a.SessionsDelete = v),
        [ClinicalView] = (a => a.ClinicalView, (a, v) => a.ClinicalView = v),
        [ClinicalEditProfile] = (a => a.ClinicalEditProfile, (a, v) => a.ClinicalEditProfile = v),
        [FilesManage] = (a => a.FilesManage, (a, v) => a.FilesManage = v),
        [PrescriptionsPrint] = (a => a.PrescriptionsPrint, (a, v) => a.PrescriptionsPrint = v),
        [PrescriptionsDraft] = (a => a.PrescriptionsDraft, (a, v) => a.PrescriptionsDraft = v),
        [Chat] = (a => a.Chat, (a, v) => a.Chat = v),
        [BillingView] = (a => a.BillingView, (a, v) => a.BillingView = v),
        [BillingPay] = (a => a.BillingPay, (a, v) => a.BillingPay = v),
        [AppointmentsView] = (a => a.AppointmentsView, (a, v) => a.AppointmentsView = v),
        [AppointmentsManage] = (a => a.AppointmentsManage, (a, v) => a.AppointmentsManage = v),
        [ScheduleManage] = (a => a.ScheduleManage, (a, v) => a.ScheduleManage = v),
        [RevenueView] = (a => a.RevenueView, (a, v) => a.RevenueView = v),
        [PricesManage] = (a => a.PricesManage, (a, v) => a.PricesManage = v),
    };
}

/// <summary>Assistants.Preset values and the permissions each preset fills in (spec 6.10).</summary>
public static class AssistantPresets
{
    public const string Reception = "reception";
    public const string Clinical = "clinical";
    public const string OfficeManager = "officeManager";
    public const string Custom = "custom";

    public static readonly IReadOnlyList<string> All = [Reception, Clinical, OfficeManager, Custom];

    public static readonly IReadOnlyDictionary<string, IReadOnlySet<string>> Permissions = new Dictionary<string, IReadOnlySet<string>>
    {
        [Reception] = new HashSet<string>
        {
            ClinicPermissions.PatientsManage, ClinicPermissions.PatientsResetPassword, ClinicPermissions.SessionsCreate,
            ClinicPermissions.FilesManage, ClinicPermissions.PrescriptionsPrint, ClinicPermissions.AppointmentsView,
            ClinicPermissions.AppointmentsManage,
        },
        [Clinical] = new HashSet<string>
        {
            ClinicPermissions.PatientsManage, ClinicPermissions.PatientsResetPassword, ClinicPermissions.SessionsCreate,
            ClinicPermissions.ClinicalView, ClinicPermissions.ClinicalEditProfile, ClinicPermissions.FilesManage,
            ClinicPermissions.PrescriptionsPrint, ClinicPermissions.PrescriptionsDraft, ClinicPermissions.Chat,
            ClinicPermissions.AppointmentsView, ClinicPermissions.AppointmentsManage,
        },
        [OfficeManager] = new HashSet<string>
        {
            ClinicPermissions.PatientsManage, ClinicPermissions.PatientsResetPassword, ClinicPermissions.SessionsCreate,
            ClinicPermissions.FilesManage, ClinicPermissions.PrescriptionsPrint, ClinicPermissions.Chat,
            ClinicPermissions.BillingView, ClinicPermissions.BillingPay, ClinicPermissions.AppointmentsView,
            ClinicPermissions.AppointmentsManage, ClinicPermissions.ScheduleManage, ClinicPermissions.PricesManage,
        },
    };

    /// <summary>The preset with exactly these permissions, or <see cref="Custom"/> ("changing any box turns the preset into Custom").</summary>
    public static string Match(IReadOnlySet<string> keys) =>
        Permissions.FirstOrDefault(pair => pair.Value.SetEquals(keys)).Key ?? Custom;
}
