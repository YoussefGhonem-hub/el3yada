using El3yada.Api.Patients;
using El3yada.Api.Sessions;
using El3yada.Data.Entities;

namespace El3yada.Api.Tests;

public sealed class ConsultationRuleTests
{
    // The BR-S3 table, with the default limit of 2.
    [Theory]
    [InlineData(0, 0, ConsultationRule.FirstVisit)] // no sessions yet
    [InlineData(1, 0, null)] // … examination
    [InlineData(1, 1, null)] // … examination → consultation
    [InlineData(1, 2, ConsultationRule.LimitReached)] // … examination → consultation → consultation
    [InlineData(3, 2, ConsultationRule.LimitReached)]
    public void A_consultation_follows_the_table(int examCount, int consultationsSinceExam, string? expected) =>
        Assert.Equal(expected, ConsultationRule.ConsultationBlockedReason(examCount, consultationsSinceExam, 2));

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 2)]
    [InlineData(5, 5)]
    public void An_examination_is_always_allowed(int examCount, int consultationsSinceExam) =>
        Assert.Null(ConsultationRule.BlockedReason(SessionTypes.Examination, examCount, consultationsSinceExam, 2));

    [Fact]
    public void The_limit_is_a_setting()
    {
        Assert.Equal(ConsultationRule.LimitReached, ConsultationRule.ConsultationBlockedReason(1, 1, 1));
        Assert.Null(ConsultationRule.ConsultationBlockedReason(1, 2, 3));
    }
}

public sealed class LinkCountersTests
{
    private static readonly Guid BranchA = Guid.NewGuid();
    private static readonly Guid BranchB = Guid.NewGuid();
    private static readonly DateTime Start = new(2026, 11, 1, 8, 0, 0, DateTimeKind.Utc);

    private static SessionFact Fact(string type, int hours, Guid? branch = null) =>
        new(Guid.NewGuid(), type, Start.AddHours(hours), branch ?? BranchA);

    [Fact]
    public void Counts_follow_the_example_in_the_spec()
    {
        // كشف → استشارة → استشارة → كشف → استشارة
        var sessions = new[]
        {
            Fact(SessionTypes.Examination, 0), Fact(SessionTypes.Consultation, 1), Fact(SessionTypes.Consultation, 2),
            Fact(SessionTypes.Examination, 3), Fact(SessionTypes.Consultation, 4, BranchB),
        };

        var counters = LinkCounters.From(sessions.Reverse());

        Assert.Equal(5, counters.SessionCount);
        Assert.Equal(2, counters.ExamCount);
        Assert.Equal(3, counters.ConsultationCount);
        Assert.Equal(1, counters.ConsultationsSinceExam);
        Assert.Equal(Start, counters.FirstSessionAt);
        Assert.Equal(sessions[^1].Id, counters.LastSessionId);
        Assert.Equal(SessionTypes.Consultation, counters.LastSessionType);
        Assert.Equal(BranchB, counters.LastSessionBranchId);
    }

    [Fact]
    public void Rebuilding_after_deleting_the_latest_gives_the_counters_before_it()
    {
        var sessions = new List<SessionFact> { Fact(SessionTypes.Examination, 0), Fact(SessionTypes.Consultation, 1) };
        var before = LinkCounters.From(sessions);

        var after = LinkCounters.From(sessions.Append(Fact(SessionTypes.Consultation, 2)).Take(2));

        Assert.Equal(before, after);
        Assert.Equal(1, after.ConsultationsSinceExam);
    }

    [Fact]
    public void No_sessions_left_clears_everything()
    {
        var link = new DoctorPatient { SessionCount = 1, ExamCount = 1, LastSessionId = Guid.NewGuid(), LastSessionType = SessionTypes.Examination };

        LinkCounters.From([]).ApplyTo(link);

        Assert.Equal(LinkCounters.Empty, LinkCounters.Of(link));
        Assert.Null(link.LastSessionType);
    }

    [Fact]
    public void An_examination_resets_the_count()
    {
        var counters = LinkCounters.Empty
            .With(Fact(SessionTypes.Examination, 0))
            .With(Fact(SessionTypes.Consultation, 1))
            .With(Fact(SessionTypes.Consultation, 2));
        Assert.Equal(2, counters.ConsultationsSinceExam);

        Assert.Equal(0, counters.With(Fact(SessionTypes.Examination, 3)).ConsultationsSinceExam);
    }
}

public sealed class VisitPriceTests
{
    [Theory]
    [InlineData(SessionTypes.Examination, 25_000, null, 30_000, 15_000, 25_000, PriceSources.Branch)]
    [InlineData(SessionTypes.Consultation, 25_000, null, 30_000, 15_000, 15_000, PriceSources.Doctor)]
    [InlineData(SessionTypes.Examination, null, null, 30_000, null, 30_000, PriceSources.Doctor)]
    [InlineData(SessionTypes.Consultation, null, null, 30_000, null, null, null)]
    [InlineData(SessionTypes.Examination, 0, null, 30_000, null, 0, PriceSources.Branch)]
    public void The_branch_price_wins_then_the_doctors_then_none(
        string type, int? branchExam, int? branchConsultation, int? doctorExam, int? doctorConsultation, int? expected, string? source)
    {
        var price = VisitPrice.For(type, branchExam, branchConsultation, doctorExam, doctorConsultation);

        Assert.Equal(expected, price.Piasters);
        Assert.Equal(source, price.Source);
    }
}

public sealed class DeleteRuleTests
{
    private static readonly DateOnly Today = new(2026, 11, 15);

    [Fact]
    public void Only_the_latest_session_of_today_can_be_deleted()
    {
        Assert.Null(DeleteRule.BlockedReason(isLatest: true, Today, Today));
        Assert.Equal(DeleteRule.NotLatest, DeleteRule.BlockedReason(isLatest: false, Today, Today));
        Assert.Equal(DeleteRule.NotSameDay, DeleteRule.BlockedReason(isLatest: true, Today.AddDays(-1), Today));
    }
}

public sealed class PatientAgeTests
{
    [Theory]
    [InlineData("1990-11-15", "2026-11-15", 36)]
    [InlineData("1990-11-16", "2026-11-15", 35)]
    [InlineData("2000-02-29", "2027-02-27", 26)]
    [InlineData("2000-02-29", "2027-02-28", 27)] // a 29 February birthday counts on the 28th in other years
    [InlineData("2026-11-15", "2026-11-15", 0)]
    public void Whole_years_to_today(string dateOfBirth, string today, int years) =>
        Assert.Equal(years, PatientAge.Years(DateOnly.Parse(dateOfBirth), DateOnly.Parse(today)));

    [Fact]
    public void An_age_gives_a_date_of_birth_with_that_age_and_dates_are_checked()
    {
        var today = new DateOnly(2026, 11, 15);

        Assert.Equal(40, PatientAge.Years(PatientAge.EstimatedDateOfBirth(40, today), today));
        Assert.True(PatientAge.IsValidDateOfBirth(today, today));
        Assert.False(PatientAge.IsValidDateOfBirth(today.AddDays(1), today));
        Assert.False(PatientAge.IsValidDateOfBirth(today.AddYears(-121), today));
    }

    [Theory]
    [InlineData("29005010123456", "29005010123456")]
    [InlineData("٢٩٠٠٥٠١٠١٢٣٤٥٦", "29005010123456")]
    [InlineData("2900501012345", null)]
    [InlineData("2900501012345x", null)]
    public void National_ids_are_14_digits(string input, string? expected) =>
        Assert.Equal(expected, NationalId.Normalize(input));
}

public sealed class FeeTotalsTests
{
    [Fact]
    public void Totals_add_examinations_and_consultations_separately()
    {
        var totals = FeeTotalsView.Zero
            .Add(SessionTypes.Examination, 2, 6000)
            .Add(SessionTypes.Consultation, 3, 4500);

        Assert.Equal(new FeeTotalsView(2, 3, 6000, 4500, 10_500), totals);
    }
}
