using System.Net;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Tests.Integration;

/// <summary>D37 and AS19 visit prices (section 6.15, BR-PR1–PR6, AC-20 branch parts).</summary>
[Collection(IntegrationCollection.Name)]
public sealed class PricesTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    [Fact]
    public async Task The_doctor_sets_doctor_and_branch_prices_and_the_history_shows_who_and_what()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var main = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var second = await TestData.AddBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/prices/updatePrices", new { examinationPricePiasters = 30000, consultationPricePiasters = 15000 });
        Assert.Equal(HttpStatusCode.OK, status);
        (status, body) = await client.PostAsync("/api/prices/updatePrices", new { branchId = second, examinationPricePiasters = 40000 });
        Assert.Equal(HttpStatusCode.OK, status);

        Assert.Equal(30000, body.GetProperty("doctor").GetProperty("examinationPricePiasters").GetInt32());
        var branches = body.GetProperty("branches").EnumerateArray().ToDictionary(b => b.Str("branchId"), b => b.GetProperty("prices"));
        Assert.True(branches[main.ToString()].GetProperty("usesDoctorPrices").GetBoolean());
        Assert.Equal(30000, branches[main.ToString()].GetProperty("effectiveExaminationPricePiasters").GetInt32());
        var own = branches[second.ToString()];
        Assert.False(own.GetProperty("usesDoctorPrices").GetBoolean());
        Assert.Equal(40000, own.GetProperty("examinationPricePiasters").GetInt32());
        Assert.Equal(JsonValueKind.Null, own.GetProperty("consultationPricePiasters").ValueKind);
        Assert.Equal(40000, own.GetProperty("effectiveExaminationPricePiasters").GetInt32());
        Assert.Equal(15000, own.GetProperty("effectiveConsultationPricePiasters").GetInt32());

        var history = body.GetProperty("history");
        Assert.Equal(2, history.GetProperty("totalCount").GetInt32());
        var newest = history.GetProperty("items")[0];
        Assert.Equal(second.ToString(), newest.GetProperty("branch").Str("id"));
        Assert.Equal("فرع مدينة نصر", newest.GetProperty("branch").Str("nameAr"));
        Assert.Equal(doctor.Id.ToString(), newest.GetProperty("changedBy").Str("userId"));
        Assert.Equal("doctor", newest.GetProperty("changedBy").Str("role"));
        Assert.Equal("أحمد علي", newest.GetProperty("changedBy").Str("name"));
        Assert.Equal(JsonValueKind.Null, newest.GetProperty("before").GetProperty("examinationPricePiasters").ValueKind);
        Assert.Equal(40000, newest.GetProperty("after").GetProperty("examinationPricePiasters").GetInt32());
        var doctorLevel = history.GetProperty("items")[1];
        Assert.Equal(JsonValueKind.Null, doctorLevel.GetProperty("branch").ValueKind);
        Assert.Equal(15000, doctorLevel.GetProperty("after").GetProperty("consultationPricePiasters").GetInt32());

        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.PricesUpdated);
        Assert.Equal(2, audit.Count);
        Assert.Equal("branch", audit[0].TargetType);
        Assert.Equal("doctor", audit[1].TargetType);
    }

    [Fact]
    public async Task Clearing_a_branch_price_goes_back_to_the_doctor_price_and_no_change_writes_no_history()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        await client.PostAsync("/api/prices/updatePrices", new { branchId = branch, examinationPricePiasters = 25000, consultationPricePiasters = 10000 });

        var (_, body) = await client.PostAsync("/api/prices/updatePrices", new { branchId = branch });
        var (_, again) = await client.PostAsync("/api/prices/updatePrices", new { branchId = branch });

        var prices = body.GetProperty("branches")[0].GetProperty("prices");
        Assert.True(prices.GetProperty("usesDoctorPrices").GetBoolean());
        // The test doctor has no prices of their own, so patients see «يُرجى الاستفسار من العيادة» (BR-PR6).
        Assert.Equal(JsonValueKind.Null, prices.GetProperty("effectiveExaminationPricePiasters").ValueKind);
        Assert.Equal(2, again.GetProperty("history").GetProperty("totalCount").GetInt32());
    }

    [Fact]
    public async Task Prices_are_checked_and_the_history_is_paged()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await client.PostAsync("/api/prices/updatePrices", new { examinationPricePiasters = -1, consultationPricePiasters = 10_000_001 });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("examinationPricePiasters"));
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("consultationPricePiasters"));

        for (var price = 1; price <= 3; price++)
        {
            await client.PostAsync("/api/prices/updatePrices", new { examinationPricePiasters = price * 1000 });
        }

        (status, body) = await client.GetJsonAsync("/api/prices?page=2&pageSize=2");
        Assert.Equal(HttpStatusCode.OK, status);
        var history = body.GetProperty("history");
        Assert.Equal(3, history.GetProperty("totalCount").GetInt32());
        Assert.Equal(2, history.GetProperty("totalPages").GetInt32());
        Assert.Equal(1000, Assert.Single(history.GetProperty("items").EnumerateArray()).GetProperty("after").GetProperty("examinationPricePiasters").GetInt32());

        (status, body) = await client.GetJsonAsync("/api/prices?pageSize=500");
        Assert.Equal(ErrorCodes.OutOfRange, body.FieldCode("pageSize"));
    }

    [Fact]
    public async Task An_assistant_with_pricesManage_sets_doctor_prices_and_their_branches_but_not_others()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branchA = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var branchB = await TestData.AddBranchAsync(Factory, doctor.Id);
        var assistant = await TestData.CreateAssistantAsync(
            Factory, doctor.Id, permissions: [ClinicPermissions.PricesManage], branchIds: [branchA], name: "منى سمير");
        using var client = await Factory.SignedInClientAsync(assistant);

        var (doctorLevel, _) = await client.PostAsync("/api/prices/updatePrices", new { examinationPricePiasters = 30000 });
        var (ownBranch, body) = await client.PostAsync("/api/prices/updatePrices", new { branchId = branchA, examinationPricePiasters = 35000 });
        var (otherBranch, refused) = await client.PostAsync("/api/prices/updatePrices", new { branchId = branchB, examinationPricePiasters = 1 });

        Assert.Equal(HttpStatusCode.OK, doctorLevel);
        Assert.Equal(HttpStatusCode.OK, ownBranch);
        Assert.Equal(HttpStatusCode.Forbidden, otherBranch);
        Assert.Equal(ErrorCodes.BranchNotAllowed, refused.Code());
        var newest = body.GetProperty("history").GetProperty("items")[0].GetProperty("changedBy");
        Assert.Equal("assistant", newest.Str("role"));
        Assert.Equal("منى سمير", newest.Str("name"));
        var assigned = body.GetProperty("branches").EnumerateArray().ToDictionary(b => b.Str("branchId"), b => b.GetProperty("assigned").GetBoolean());
        Assert.True(assigned[branchA.ToString()]);
        Assert.False(assigned[branchB.ToString()]);
        var branchBPrice = await TestData.WithDbAsync(Factory, db => db.Branches.Where(b => b.Id == branchB).Select(b => b.ExaminationPricePiasters).SingleAsync());
        Assert.Null(branchBPrice);
        var audit = await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.PricesUpdated);
        Assert.All(audit, a => Assert.Equal(assistant.Id, a.ActorUserId));
    }
}
