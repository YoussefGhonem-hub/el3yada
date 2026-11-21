using El3yada.Api.Billing;
using El3yada.Api.Doctors;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// <c>trialReminders</c> (spec 6.16, BR-T6 [S]): 3 days before the free trial ends and on its last day, to the doctor
/// and their active assistants, once per window, from the daily billing jobs.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class TrialReminderTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private Task SetTrialAsync(Guid doctorId, DateTime? endsAt) =>
        TestData.WithDbAsync(Factory, db => db.Doctors.Where(d => d.UserId == doctorId)
            .ExecuteUpdateAsync(set => set.SetProperty(d => d.TrialEndsAt, endsAt)));

    /// <summary>Runs the job, and the notifications it writes, with the clock stopped at <paramref name="now"/>.</summary>
    private async Task<int> RunAtAsync(DateTime now)
    {
        await using var scope = Factory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var clock = new StoppedClock(new DateTimeOffset(now, TimeSpan.Zero));
        return await new TrialReminders(db, new NotificationWriter(db, clock), clock).SendAsync(CancellationToken.None);
    }

    private Task<List<Notification>> RemindersAsync(params Guid[] users) =>
        TestData.WithDbAsync(Factory, db => db.Notifications.AsNoTracking()
            .Where(n => users.Contains(n.RecipientUserId) && (n.Type == "trialEndingSoon" || n.Type == "trialLastDay"))
            .OrderBy(n => n.CreatedAt)
            .ToListAsync());

    [Fact]
    public async Task Three_days_before_then_on_the_last_day_once_each_to_the_doctor_and_active_assistants()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var assistant = await TestData.CreateAssistantAsync(Factory, doctor.Id, name: "سارة محمود");
        var disabled = await TestData.CreateAssistantAsync(Factory, doctor.Id, status: "disabled");
        var start = DateTime.UtcNow;
        var endsAt = start.AddDays(2).AddHours(12);   // daysLeft 3, as the banner counts
        await SetTrialAsync(doctor.Id, endsAt);

        await RunAtAsync(start);
        await RunAtAsync(start.AddHours(1));           // a restart or a second server the same day
        await RunAtAsync(start.AddDays(1));            // daysLeft 2: still the same window

        var soon = await RemindersAsync(doctor.Id, assistant.Id, disabled.Id);
        Assert.Equal(2, soon.Count);
        var toDoctor = soon.Single(n => n.RecipientUserId == doctor.Id);
        Assert.Equal("trialEndingSoon", toDoctor.Type);
        Assert.Equal("باقي 3 أيام على نهاية الفترة التجريبية المجانية. تواصل معنا لتفعيل الخدمة ومواصلة استخدام العيادة.", toDoctor.BodyAr);
        Assert.Equal("Your free trial ends in 3 days. Contact us to activate the service and keep using your clinic.", toDoctor.BodyEn);
        Assert.Equal("/doctor/settings", toDoctor.Route);
        Assert.Contains(doctor.Id.ToString(), toDoctor.DataJson);
        var toAssistant = soon.Single(n => n.RecipientUserId == assistant.Id);
        Assert.Contains("لعيادة د. أحمد علي", toAssistant.BodyAr);
        Assert.Contains("اطلب من الطبيب التواصل معنا", toAssistant.BodyAr);
        Assert.Equal("/assistant/settings", toAssistant.Route);

        // Less than a day left: the last-day reminder, once.
        await RunAtAsync(start.AddDays(2));
        await RunAtAsync(start.AddDays(2).AddHours(3));
        var all = await RemindersAsync(doctor.Id, assistant.Id, disabled.Id);
        Assert.Equal(4, all.Count);
        var last = all.Where(n => n.Type == "trialLastDay").ToList();
        Assert.Equal(new[] { doctor.Id, assistant.Id }.Order(), last.Select(n => n.RecipientUserId).Order());
        Assert.Equal("تنتهي الفترة التجريبية المجانية خلال 24 ساعة. تواصل معنا لتفعيل الخدمة ومواصلة استخدام العيادة.", last.Single(n => n.RecipientUserId == doctor.Id).BodyAr);

        // After the end: nothing more (A15 takes over).
        await RunAtAsync(endsAt.AddHours(1));
        Assert.Equal(4, (await RemindersAsync(doctor.Id, assistant.Id, disabled.Id)).Count);
        Assert.Empty(await RemindersAsync(disabled.Id));
    }

    [Fact]
    public async Task No_reminder_without_a_trial_far_from_the_end_or_for_a_disabled_account()
    {
        var now = DateTime.UtcNow;
        var active = await TestData.CreateDoctorAsync(Factory);
        var far = await TestData.CreateDoctorAsync(Factory);
        var ended = await TestData.CreateDoctorAsync(Factory);
        var disabled = await TestData.CreateDoctorAsync(Factory, userStatus: "disabled");
        await SetTrialAsync(active.Id, null);
        await SetTrialAsync(far.Id, now.AddDays(5));
        await SetTrialAsync(ended.Id, now.AddHours(-2));
        await SetTrialAsync(disabled.Id, now.AddDays(1));

        await RunAtAsync(now);

        Assert.Empty(await RemindersAsync(active.Id, far.Id, ended.Id, disabled.Id));
    }

    [Fact]
    public async Task An_extended_trial_gets_its_reminders_again_for_the_new_end()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var start = DateTime.UtcNow;
        await SetTrialAsync(doctor.Id, start.AddDays(2));
        await RunAtAsync(start);
        Assert.Single(await RemindersAsync(doctor.Id));

        // The admin adds 7 days (BR-T5): the old reminder is before the new window.
        var newEnd = start.AddDays(9);
        await SetTrialAsync(doctor.Id, newEnd);
        await RunAtAsync(start.AddDays(1));            // 8 days left: nothing yet
        Assert.Single(await RemindersAsync(doctor.Id));
        await RunAtAsync(newEnd.AddDays(-2.5));
        var reminders = await RemindersAsync(doctor.Id);
        Assert.Equal(2, reminders.Count);
        Assert.Contains("Your free trial ends in 3 days.", reminders[1].BodyEn);
    }

    [Fact]
    public async Task The_daily_billing_jobs_run_it()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        await SetTrialAsync(doctor.Id, DateTime.UtcNow.AddHours(30));   // daysLeft 2

        await using var scope = Factory.CreateScope();
        var jobs = scope.ServiceProvider.GetRequiredService<BillingJobs>();
        await jobs.RunAsync("trialReminders", jobs.TrialRemindersAsync, CancellationToken.None);

        var reminder = Assert.Single(await RemindersAsync(doctor.Id));
        Assert.Equal("باقي يومين على نهاية الفترة التجريبية المجانية. تواصل معنا لتفعيل الخدمة ومواصلة استخدام العيادة.", reminder.BodyAr);
        Assert.DoesNotContain("trialReminders", scope.ServiceProvider.GetRequiredService<JobStatus>().Failing);
    }
}
