using System.Globalization;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data.Entities;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// The booking phrases of the notifications (spec 10.1, BR-AP16), in Egyptian clinic Arabic and in English.
/// In queue mode a booking has no number before check-in, so the texts give the period and say that turns go
/// in order of arrival (BR-AP3).
/// </summary>
public static class AppointmentTexts
{
    private static readonly CultureInfo Arabic = CultureInfo.GetCultureInfo("ar-EG");
    private static readonly CultureInfo English = CultureInfo.GetCultureInfo("en-GB");

    /// <summary>Morning before 15:00, as in the search filter (6.12.8).</summary>
    public static (string Ar, string En) PeriodName(TimeOnly start) => start < new TimeOnly(15, 0)
        ? ("الفترة الصباحية", "morning period")
        : ("الفترة المسائية", "evening period");

    /// <summary>«6 مساءً», «6:15 مساءً», «12 ظهراً» / "6 pm", "6:15 pm".</summary>
    public static (string Ar, string En) Clock(TimeOnly time)
    {
        var hour12 = time.Hour % 12 == 0 ? 12 : time.Hour % 12;
        var digits = time.Minute == 0 ? $"{hour12}" : $"{hour12}:{time.Minute:00}";
        var ar = time.Hour switch
        {
            < 12 => "صباحاً",
            12 => "ظهراً",
            _ => "مساءً",
        };
        return ($"{digits} {ar}", $"{digits} {(time.Hour < 12 ? "am" : "pm")}");
    }

    public static (string Ar, string En) Day(DateOnly date) =>
        (date.ToString("dddd d MMMM", Arabic), date.ToString("dddd d MMMM", English));

    /// <summary>
    /// When the booking is, without a number: «السبت 22 نوفمبر، الفترة المسائية من 6 مساءً» (queue) or
    /// «السبت 22 نوفمبر الساعة 6:15 مساءً» (timed).
    /// </summary>
    public static (string Ar, string En) When(Appointment a)
    {
        var day = Day(a.LocalDate);
        return a.Mode == "queue" ? (
            $"{day.Ar}، {PeriodName(a.PeriodStartLocal).Ar} من {Clock(a.PeriodStartLocal).Ar}",
            $"{day.En}, {PeriodName(a.PeriodStartLocal).En} from {Clock(a.PeriodStartLocal).En}")
            : AtTime(day, TimeOnly.FromDateTime(CairoTime.ToCairo(a.StartUtc)));
    }

    /// <summary>
    /// The reminder (BR-AP16). Queue mode, on the day: «اليوم موعدك في فرع المعادي، الفترة المسائية من 6 مساءً.
    /// الدور بأسبقية الحضور: سجّل حضورك في الاستقبال عند وصولك.» Timed: «تذكير: موعدك اليوم الساعة 6:15 مساءً — فرع المعادي».
    /// </summary>
    /// <param name="sentOn">The Cairo date the reminder goes out: the same day, the day before, or earlier.</param>
    public static (string Ar, string En) Reminder(Appointment a, string branchAr, string branchEn, DateOnly sentOn)
    {
        var sameDay = sentOn == a.LocalDate;
        var dayAr = sameDay ? "اليوم" : sentOn.AddDays(1) == a.LocalDate ? "غداً" : $"يوم {Day(a.LocalDate).Ar}";
        var dayEn = sameDay ? "today" : sentOn.AddDays(1) == a.LocalDate ? "tomorrow" : $"on {Day(a.LocalDate).En}";
        if (a.Mode == "queue")
        {
            var period = PeriodName(a.PeriodStartLocal);
            var clock = Clock(a.PeriodStartLocal);
            return sameDay
                ? ($"اليوم موعدك في {branchAr}، {period.Ar} من {clock.Ar}. الدور بأسبقية الحضور: سجّل حضورك في الاستقبال عند وصولك.",
                   $"Your appointment is today at {branchEn}, {period.En} from {clock.En}. Turns go in order of arrival: check in at reception when you arrive.")
                : ($"تذكير: موعدك {dayAr}، {period.Ar} من {clock.Ar} — {branchAr}. الدور بأسبقية الحضور.",
                   $"Reminder: your appointment is {dayEn}, {period.En} from {clock.En} — {branchEn}. Turns go in order of arrival.");
        }
        var time = Clock(TimeOnly.FromDateTime(CairoTime.ToCairo(a.StartUtc)));
        return ($"تذكير: موعدك {dayAr} الساعة {time.Ar} — {branchAr}", $"Reminder: your appointment is {dayEn} at {time.En} — {branchEn}");
    }

    /// <summary>«قبلك 3 مرضى» with the Arabic number forms; "3 patients ahead of you".</summary>
    public static (string Ar, string En) Ahead(int ahead) => (
        ahead switch
        {
            0 => "وأنت التالي",
            1 => "وقبلك مريض واحد",
            2 => "وقبلك مريضان",
            <= 10 => $"وقبلك {ahead} مرضى",
            _ => $"وقبلك {ahead} مريضاً",
        },
        ahead switch
        {
            0 => "you're next",
            1 => "1 patient is ahead of you",
            _ => $"{ahead} patients are ahead of you",
        });

    /// <summary>«حوالي 30 دقيقة» / "about 30 minutes".</summary>
    public static (string Ar, string En) Minutes(int minutes) => (
        minutes switch
        {
            1 => "حوالي دقيقة",
            2 => "حوالي دقيقتين",
            <= 10 => $"حوالي {minutes} دقائق",
            _ => $"حوالي {minutes} دقيقة",
        },
        minutes == 1 ? "about 1 minute" : $"about {minutes} minutes");

    private static (string Ar, string En) AtTime((string Ar, string En) day, TimeOnly time)
    {
        var clock = Clock(time);
        return ($"{day.Ar} الساعة {clock.Ar}", $"{day.En} at {clock.En}");
    }
}
