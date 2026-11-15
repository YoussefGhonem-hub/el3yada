using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Data.Entities;

namespace El3yada.Api.Tests;

public sealed class ClinicPermissionsTests
{
    [Fact]
    public void Dependencies_follow_chains()
    {
        var keys = ClinicPermissions.WithDependencies([ClinicPermissions.ScheduleManage, ClinicPermissions.BillingPay]);

        Assert.Equal(
            new HashSet<string>
            {
                ClinicPermissions.ScheduleManage, ClinicPermissions.AppointmentsManage, ClinicPermissions.AppointmentsView,
                ClinicPermissions.BillingPay, ClinicPermissions.BillingView,
            },
            keys);
    }

    [Fact]
    public void Unknown_keys_are_dropped() =>
        Assert.Empty(ClinicPermissions.WithDependencies(["deleteEverything"]));

    [Fact]
    public void Presets_are_closed_under_their_dependencies()
    {
        foreach (var (_, keys) in AssistantPresets.Permissions)
        {
            Assert.Equal(keys, ClinicPermissions.WithDependencies(keys));
        }
    }

    [Fact]
    public void A_preset_is_matched_and_any_change_makes_it_custom()
    {
        var reception = AssistantPresets.Permissions[AssistantPresets.Reception];
        Assert.Equal(AssistantPresets.Reception, AssistantPresets.Match(reception));
        Assert.Equal(AssistantPresets.Custom, AssistantPresets.Match(reception.Append(ClinicPermissions.Chat).ToHashSet()));
    }

    [Fact]
    public void Apply_and_read_back_every_column()
    {
        foreach (var key in ClinicPermissions.All)
        {
            var assistant = new Assistant();
            ClinicPermissions.Apply(assistant, new HashSet<string> { key });
            Assert.Equal([key], ClinicPermissions.Of(assistant));
        }
    }
}

public sealed class SearchTextTests
{
    [Theory]
    [InlineData("أحمد", "احمد")]
    [InlineData("إيمان", "ايمان")]
    [InlineData("آمال", "امال")]
    [InlineData("منة الله", "منه الله")]
    [InlineData("مُصطفى", "مصطفي")]
    [InlineData("محـــمد", "محمد")]
    [InlineData("  Mona   HASSAN ", "mona hassan")]
    [InlineData("٠١٠١٢٣٤٥٦٧٨", "01012345678")]
    [InlineData("Augmentin 1g, (14 tabs)", "augmentin 1g 14 tabs")]
    [InlineData("250/5 ml", "250/5 ml")]
    [InlineData("0.1%", "0.1")]
    [InlineData("end.", "end")]
    [InlineData(null, "")]
    public void Normalizes_like_the_app(string? input, string expected) =>
        Assert.Equal(expected, SearchText.Normalize(input));
}

public sealed class CairoTimeTests
{
    [Fact]
    public void A_late_evening_utc_time_is_the_next_cairo_day()
    {
        // 23:30 UTC on 14 Nov is 01:30 on 15 Nov in Cairo (UTC+2 in November).
        var utc = new DateTime(2026, 11, 14, 23, 30, 0, DateTimeKind.Utc);
        Assert.Equal(new DateOnly(2026, 11, 15), CairoTime.DayOf(utc));
        Assert.Equal("2026-11", CairoTime.MonthKey(utc));
    }

    [Fact]
    public void A_day_range_covers_the_cairo_day()
    {
        var (start, end) = CairoTime.DayRangeUtc(new DateOnly(2026, 11, 15));
        Assert.Equal(new DateTime(2026, 11, 14, 22, 0, 0, DateTimeKind.Utc), start);
        Assert.Equal(TimeSpan.FromHours(24), end - start);
    }

    [Fact]
    public void Summer_time_is_applied()
    {
        // Egypt uses UTC+3 in summer: 21:30 UTC on 1 Aug is 00:30 on 2 Aug.
        Assert.Equal(new DateOnly(2026, 8, 2), CairoTime.DayOf(new DateTime(2026, 8, 1, 21, 30, 0, DateTimeKind.Utc)));
    }

    [Theory]
    [InlineData("2026-11", 2026, 11)]
    [InlineData("2026-13", 0, 0)]
    [InlineData("nope", 0, 0)]
    public void Month_keys_parse(string key, int year, int month)
    {
        var parsed = CairoTime.ParseMonthKey(key);
        Assert.Equal(year == 0 ? null : new DateOnly(year, month, 1), parsed);
    }
}
