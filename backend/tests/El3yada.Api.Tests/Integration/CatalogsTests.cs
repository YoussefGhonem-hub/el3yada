using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using El3yada.Api.Catalogs;
using El3yada.Api.Clinic;
using El3yada.Api.Commands;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// Catalogs (spec 6.9, 9.5, D0, AD19, AD20, AC-18): publishing, downloads, custom items, reports, specialty profiles and
/// the seed command. Contract: api-phase-3-catalogs.md.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class CatalogsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    /// <summary>A catalog like the builder makes: meta as key/value rows, and the three item tables.</summary>
    private static byte[] BuildCatalog(int drugs, int labs, int radiology, int schemaVersion = CatalogSchema.ExpectedVersion)
    {
        var database = Path.Combine(Path.GetTempPath(), $"catalog-test-{Guid.NewGuid():N}.sqlite");
        try
        {
            using (var connection = new SqliteConnection($"Data Source={database};Pooling=False"))
            {
                connection.Open();
                using var command = connection.CreateCommand();
                command.CommandText = """
                    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
                    CREATE TABLE drugs (id INTEGER PRIMARY KEY, trade_name_en TEXT);
                    CREATE TABLE lab_tests (loinc_code TEXT PRIMARY KEY, name_en TEXT);
                    CREATE TABLE radiology (loinc_code TEXT PRIMARY KEY, name_en TEXT);
                    """;
                command.ExecuteNonQuery();
                void Insert(string sql)
                {
                    using var insert = connection.CreateCommand();
                    insert.CommandText = sql;
                    insert.ExecuteNonQuery();
                }

                Insert($"INSERT INTO meta VALUES ('schema_version','{schemaVersion}'),('catalog_version','7'),('built_at','2026-11-17T10:00:00Z'),('drug_source_date','2026-06-30'),('loinc_release','2.83')");
                for (var i = 0; i < drugs; i++)
                {
                    Insert($"INSERT INTO drugs VALUES ({i}, 'DRUG {i}')");
                }

                for (var i = 0; i < labs; i++)
                {
                    Insert($"INSERT INTO lab_tests VALUES ('{i}-1', 'LAB {i}')");
                }

                for (var i = 0; i < radiology; i++)
                {
                    Insert($"INSERT INTO radiology VALUES ('R{i}-1', 'RAD {i}')");
                }
            }

            using var output = new MemoryStream();
            using (var gzip = new GZipStream(output, CompressionLevel.SmallestSize, leaveOpen: true))
            using (var input = File.OpenRead(database))
            {
                input.CopyTo(gzip);
            }

            return output.ToArray();
        }
        finally
        {
            File.Delete(database);
        }
    }

    private static string Manifest(byte[] file, string? sha = null) => JsonSerializer.Serialize(new
    {
        catalog_version = 7, schema_version = 1, sha256 = sha ?? Convert.ToHexStringLower(SHA256.HashData(file)), size_bytes = file.Length,
    });

    private static async Task<(HttpStatusCode Status, JsonElement Body)> PublishAsync(HttpClient client, byte[] file, string? manifest, bool confirmDrop = false)
    {
        using var form = new MultipartFormDataContent();
        var part = new ByteArrayContent(file);
        part.Headers.ContentType = new MediaTypeHeaderValue("application/gzip");
        form.Add(part, "file", "catalog-v7.sqlite.gz");
        if (manifest is not null)
        {
            form.Add(new ByteArrayContent(Encoding.UTF8.GetBytes(manifest)), "manifest", "catalog-v7.json");
        }

        if (confirmDrop)
        {
            form.Add(new StringContent("true"), "confirmDrop");
        }

        using var response = await client.PostAsync("/api/admin/publishCatalog", form);
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    [Fact]
    public async Task Publishing_checks_the_file_and_rolls_out_the_next_version()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var good = BuildCatalog(200, 100, 50);
        var before = await TestData.WithDbAsync(Factory, db => db.CatalogVersions.MaxAsync(v => (int?)v.VersionNumber)) ?? 0;

        var (shaStatus, sha) = await PublishAsync(asAdmin, good, Manifest(good, new string('0', 64)));
        var notSqlite = Compress(Encoding.UTF8.GetBytes("hello"));
        var (_, invalid) = await PublishAsync(asAdmin, notSqlite, Manifest(notSqlite));
        var notGzip = Encoding.UTF8.GetBytes("plain text");
        var (_, notGz) = await PublishAsync(asAdmin, notGzip, Manifest(notGzip));
        var future = BuildCatalog(200, 100, 50, schemaVersion: 99);
        var (_, schema) = await PublishAsync(asAdmin, future, Manifest(future));
        var (_, noManifest) = await PublishAsync(asAdmin, good, null);
        Assert.Equal(HttpStatusCode.BadRequest, shaStatus);
        Assert.Equal(ErrorCodes.CatalogShaMismatch, sha.FieldCode("file"));
        Assert.Equal(ErrorCodes.CatalogFileInvalid, invalid.FieldCode("file"));
        Assert.Equal(ErrorCodes.CatalogFileInvalid, notGz.FieldCode("file"));
        Assert.Equal(ErrorCodes.CatalogSchemaUnsupported, schema.FieldCode("file"));
        Assert.Equal(99, schema.GetProperty("actual").GetInt32());
        Assert.Equal(ErrorCodes.Required, noManifest.FieldCode("manifest"));

        var (status, published) = await PublishAsync(asAdmin, good, Manifest(good));
        Assert.Equal(HttpStatusCode.Created, status);
        var version = published.GetProperty("version").GetInt32();
        Assert.Equal(before + 1, version);
        Assert.Equal(200, published.GetProperty("counts").GetProperty("drugs").GetInt32());
        Assert.Equal("2.83", published.Str("loincRelease"));
        Assert.Equal("2026-06-30", published.Str("drugSourceDate"));
        Assert.Equal($"/api/catalog/file/{version}", published.Str("downloadPath"));

        var (_, current) = await client.GetJsonAsync("/api/catalog/current");
        Assert.Equal(version, current.GetProperty("version").GetInt32());
        var (_, settings) = await Factory.Client().GetJsonAsync("/api/settings/public");
        Assert.Equal(version, settings.GetProperty("catalog").GetProperty("version").GetInt32());
        Assert.Equal(published.Str("sha256"), settings.GetProperty("catalog").Str("sha256"));

        // A much smaller catalog needs confirmation.
        var smaller = BuildCatalog(180, 100, 50);
        var (dropStatus, drop) = await PublishAsync(asAdmin, smaller, Manifest(smaller));
        Assert.Equal(HttpStatusCode.Conflict, dropStatus);
        Assert.Equal(ErrorCodes.CatalogCountDrop, drop.Code());
        var dropped = Assert.Single(drop.GetProperty("drops").EnumerateArray());
        Assert.Equal("drugs", dropped.Str("table"));
        var (confirmedStatus, confirmed) = await PublishAsync(asAdmin, smaller, Manifest(smaller), confirmDrop: true);
        Assert.Equal(HttpStatusCode.Created, confirmedStatus);
        Assert.Equal(version + 1, confirmed.GetProperty("version").GetInt32());

        var (_, versions) = await asAdmin.GetJsonAsync("/api/admin/catalogVersions");
        var latest = versions[0];
        Assert.True(latest.GetProperty("current").GetBoolean());
        Assert.Equal(version + 1, latest.GetProperty("version").GetProperty("version").GetInt32());
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "catalogPublished" && a.ActorUserId == admin.Id)));
    }

    [Fact]
    public async Task Doctors_admins_and_drafting_assistants_download_the_file_with_ranges_and_patients_never()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var catalog = BuildCatalog(300, 120, 60);
        var (_, published) = await PublishAsync(asAdmin, catalog, Manifest(catalog), confirmDrop: true);
        var version = published.GetProperty("version").GetInt32();
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var clinical = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Clinical);
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        var (patient, _) = await TestData.CreatePatientAsync(Factory);
        using var asClinical = await Factory.SignedInClientAsync(clinical);
        using var asReception = await Factory.SignedInClientAsync(reception);
        using var asPatient = await Factory.SignedInClientAsync(patient);
        var url = $"/api/catalog/file/{version}";

        using var full = await asDoctor.GetAsync(url);
        Assert.Equal(HttpStatusCode.OK, full.StatusCode);
        Assert.Equal(catalog, await full.Content.ReadAsByteArrayAsync());
        Assert.Equal("application/gzip", full.Content.Headers.ContentType?.MediaType);
        Assert.Contains("bytes", full.Headers.AcceptRanges);

        using var partRequest = new HttpRequestMessage(HttpMethod.Get, url);
        partRequest.Headers.Range = new RangeHeaderValue(10, 19);
        using var part = await asClinical.SendAsync(partRequest);
        Assert.Equal(HttpStatusCode.PartialContent, part.StatusCode);
        Assert.Equal(catalog[10..20], await part.Content.ReadAsByteArrayAsync());

        using var byAdmin = await asAdmin.GetAsync(url);
        using var byReception = await asReception.GetAsync(url);
        using var byPatient = await asPatient.GetAsync(url);
        using var missing = await asDoctor.GetAsync("/api/catalog/file/99999");
        Assert.Equal(HttpStatusCode.OK, byAdmin.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, byReception.StatusCode);
        Assert.Equal(ClinicPermissions.PrescriptionsDraft, (await Http.BodyAsync(byReception)).Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, byPatient.StatusCode);
        Assert.Equal(ErrorCodes.Forbidden, (await Http.BodyAsync(byPatient)).Code());
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        var (patientCurrent, _) = await asPatient.GetJsonAsync("/api/catalog/current");
        Assert.Equal(HttpStatusCode.Forbidden, patientCurrent);
    }

    [Fact]
    public async Task Custom_items_reach_devices_through_sync_and_disabling_is_synced_too()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var (_, doctor, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var (_, start) = await doctor.GetJsonAsync("/api/catalog/customItems");
        var since = start.GetProperty("nextSince").ValueKind == JsonValueKind.Null ? null : start.Str("nextSince");

        var (createStatus, created) = await asAdmin.PostAsync("/api/admin/catalog/createCustomItem", new
        {
            type = "drug", nameEn = "  Newcillin   500 ", nameAr = "نيوسيلين", activeIngredient = "amoxicillin", drugGroupId = "antibiotics",
            route = "oral", aliases = new[] { "newcil", "NEWCIL", "نيو" },
        });
        var (labStatus, lab) = await asAdmin.PostAsync("/api/admin/catalog/createCustomItem", new { type = "lab", nameEn = "Anti-Xa", loincCode = "3274-8" });
        var (badStatus, bad) = await asAdmin.PostAsync("/api/admin/catalog/createCustomItem", new { type = "lab", nameEn = "X", route = "oral" });
        var (doctorCreate, _) = await doctor.PostAsync("/api/admin/catalog/createCustomItem", new { type = "lab", nameEn = "X" });
        Assert.Equal(HttpStatusCode.Created, createStatus);
        Assert.Equal("Newcillin 500", created.Str("nameEn"));
        Assert.Equal(["newcil", "نيو"], created.GetProperty("aliases").EnumerateArray().Select(a => a.GetString()));
        Assert.Equal(HttpStatusCode.Created, labStatus);
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("route"));
        Assert.Equal(HttpStatusCode.Forbidden, doctorCreate);

        var sinceQuery = since is null ? "" : $"?since={Uri.EscapeDataString(since)}";
        var (_, sync) = await doctor.GetJsonAsync($"/api/catalog/customItems{sinceQuery}");
        var ids = sync.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("customItemId").GetGuid()).ToList();
        Assert.Contains(created.GetProperty("customItemId").GetGuid(), ids);
        Assert.Contains(lab.GetProperty("customItemId").GetGuid(), ids);
        Assert.False(sync.GetProperty("hasMore").GetBoolean());
        var next = sync.Str("nextSince");

        var (updateStatus, updated) = await asAdmin.PostAsync("/api/admin/catalog/updateCustomItem", new
        {
            customItemId = lab.GetProperty("customItemId").GetGuid(), nameEn = "Anti-Xa (heparin)", loincCode = "3274-8", active = false,
        });
        var (wrongField, wrong) = await asAdmin.PostAsync("/api/admin/catalog/updateCustomItem", new
        {
            customItemId = lab.GetProperty("customItemId").GetGuid(), nameEn = "x", drugGroupId = "antibiotics", active = true,
        });
        Assert.Equal(HttpStatusCode.OK, updateStatus);
        Assert.False(updated.GetProperty("active").GetBoolean());
        Assert.Equal(HttpStatusCode.BadRequest, wrongField);
        Assert.Equal(ErrorCodes.InvalidValue, wrong.FieldCode("drugGroupId"));

        var (_, afterDisable) = await doctor.GetJsonAsync($"/api/catalog/customItems?since={Uri.EscapeDataString(next)}");
        var changed = Assert.Single(afterDisable.GetProperty("items").EnumerateArray());
        Assert.False(changed.GetProperty("active").GetBoolean());

        var (_, inactive) = await asAdmin.GetJsonAsync("/api/admin/catalog/customItems?type=lab&active=false&search=Anti-Xa");
        Assert.Contains(inactive.GetProperty("items").EnumerateArray(), i => i.GetProperty("customItemId").GetGuid() == lab.GetProperty("customItemId").GetGuid());
    }

    [Fact]
    public async Task Doctors_report_items_and_admins_handle_them()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var assistant = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Clinical);
        using var asAssistant = await Factory.SignedInClientAsync(assistant);

        var (status, report) = await asDoctor.PostAsync("/api/catalog/reportCatalogItem", new { type = "missing", text = "Ketofan 100 mg is missing", itemRef = "search:ketofan" });
        var (badStatus, bad) = await asDoctor.PostAsync("/api/catalog/reportCatalogItem", new { type = "broken", text = "x" });
        var (assistantStatus, _) = await asAssistant.PostAsync("/api/catalog/reportCatalogItem", new { type = "other", text = "x" });
        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("open", report.Str("status"));
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("type"));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(HttpStatusCode.Forbidden, assistantStatus);
        Assert.True(await TestData.WithDbAsync(Factory, db => db.Notifications.AnyAsync(n => n.RecipientUserId == admin.Id && n.Type == "catalogReportReceived")));

        var reportId = report.GetProperty("reportId").GetGuid();
        var (_, open) = await asAdmin.GetJsonAsync("/api/admin/catalog/reports?pageSize=100");
        Assert.Contains(open.GetProperty("items").EnumerateArray(), r => r.GetProperty("reportId").GetGuid() == reportId && r.Str("doctorName") == "أحمد علي");
        var (handleStatus, handled) = await asAdmin.PostAsync("/api/admin/catalog/handleReport", new { reportId });
        Assert.Equal(HttpStatusCode.OK, handleStatus);
        Assert.Equal("done", handled.Str("status"));
        Assert.Equal(admin.Id, handled.GetProperty("handledBy").GetGuid());
        var (_, stillOpen) = await asAdmin.GetJsonAsync("/api/admin/catalog/reports?pageSize=100");
        Assert.DoesNotContain(stillOpen.GetProperty("items").EnumerateArray(), r => r.GetProperty("reportId").GetGuid() == reportId);
    }

    [Fact]
    public async Task Specialty_profiles_are_edited_by_admins_and_merged_with_General_for_doctors()
    {
        var admin = await TestData.CreateAdminAsync(Factory);
        using var asAdmin = await Factory.SignedInClientAsync(admin);
        var cardiology = await TestData.WithDbAsync(Factory, db => db.Specialties.Where(s => s.NameEn == "Cardiology").Select(s => s.Id).SingleAsync());
        var internal_ = await TestData.WithDbAsync(Factory, db => db.Specialties.Where(s => s.NameEn == "Internal Medicine").Select(s => s.Id).SingleAsync());
        var general = await TestData.WithDbAsync(Factory, db => db.Specialties.Where(s => s.NameEn == "General").Select(s => s.Id).SingleAsync());
        var doctor = await TestData.CreateDoctorAsync(Factory);
        await TestData.WithDbAsync(Factory, async db =>
        {
            var row = await db.Doctors.Include(d => d.Specialties).SingleAsync(d => d.UserId == doctor.Id);
            row.SpecialtyId = cardiology;
            row.Specialties.Add(await db.Specialties.SingleAsync(s => s.Id == internal_));
            await db.SaveChangesAsync();
        });
        using var asDoctor = await Factory.SignedInClientAsync(doctor);

        var (listStatus, list) = await asAdmin.GetJsonAsync("/api/admin/specialties");
        Assert.Equal(HttpStatusCode.OK, listStatus);
        Assert.True(list[0].GetProperty("isGeneral").GetBoolean());
        var cardiologyRow = list.EnumerateArray().Single(s => s.GetProperty("specialtyId").GetGuid() == cardiology);
        Assert.True(cardiologyRow.GetProperty("doctorCount").GetInt32() >= 1);

        var (putStatus, put) = await asAdmin.PutAsync($"/api/admin/specialties/{cardiology}/profile", new
        {
            includeGeneral = true, drugGroups = new[] { "statins", "antiplatelets", "statins" }, labCodes = new[] { "2093-3" },
            radiologyModalities = new[] { "US" }, radiologyRegions = new[] { "Heart" },
        });
        await asAdmin.PutAsync($"/api/admin/specialties/{internal_}/profile", new { includeGeneral = true, drugGroups = new[] { "antidiabetics" }, labCodes = new[] { "4548-4" } });
        await asAdmin.PutAsync($"/api/admin/specialties/{general}/profile", new { includeGeneral = true, drugGroups = new[] { "analgesics", "ppis" }, labCodes = new[] { "58410-2" } });
        var (badStatus, bad) = await asAdmin.PutAsync($"/api/admin/specialties/{cardiology}/profile", new { includeGeneral = true, drugGroups = new[] { "مضادات" } });
        var (doctorPut, _) = await asDoctor.PutAsync($"/api/admin/specialties/{cardiology}/profile", new { includeGeneral = true });
        Assert.Equal(HttpStatusCode.OK, putStatus);
        Assert.Equal(["antiplatelets", "statins"], put.GetProperty("drugGroups").EnumerateArray().Select(g => g.GetString()));
        Assert.Equal(HttpStatusCode.BadRequest, badStatus);
        Assert.Equal(ErrorCodes.InvalidValue, bad.FieldCode("drugGroups"));
        Assert.Equal(HttpStatusCode.Forbidden, doctorPut);
        var (_, generalView) = await asAdmin.GetJsonAsync($"/api/admin/specialties/{general}/profile");
        Assert.True(generalView.GetProperty("isGeneral").GetBoolean());
        Assert.False(generalView.GetProperty("includeGeneral").GetBoolean());

        // BR-CAT2–CAT4: primary + extra + General.
        var (_, mine) = await asDoctor.GetJsonAsync("/api/catalog/myProfile");
        Assert.True(mine.GetProperty("includesGeneral").GetBoolean());
        Assert.Equal(["analgesics", "antidiabetics", "antiplatelets", "ppis", "statins"], mine.GetProperty("drugGroups").EnumerateArray().Select(g => g.GetString()));
        Assert.Equal(["2093-3", "4548-4", "58410-2"], mine.GetProperty("labCodes").EnumerateArray().Select(g => g.GetString()));

        // Without General.
        await asAdmin.PutAsync($"/api/admin/specialties/{cardiology}/profile", new { includeGeneral = false, drugGroups = new[] { "statins" } });
        await asAdmin.PutAsync($"/api/admin/specialties/{internal_}/profile", new { includeGeneral = false, drugGroups = new[] { "antidiabetics" } });
        var (_, without) = await asDoctor.GetJsonAsync("/api/catalog/myProfile");
        Assert.False(without.GetProperty("includesGeneral").GetBoolean());
        Assert.Equal(["antidiabetics", "statins"], without.GetProperty("drugGroups").EnumerateArray().Select(g => g.GetString()));

        // Copy from another specialty.
        var (copyStatus, copied) = await asAdmin.PostAsync($"/api/admin/specialties/{internal_}/copyProfile", new { fromSpecialtyId = general });
        Assert.Equal(HttpStatusCode.OK, copyStatus);
        Assert.Equal(["analgesics", "ppis"], copied.GetProperty("drugGroups").EnumerateArray().Select(g => g.GetString()));
        Assert.True(copied.GetProperty("includeGeneral").GetBoolean());
        var (selfCopy, selfCopyBody) = await asAdmin.PostAsync($"/api/admin/specialties/{internal_}/copyProfile", new { fromSpecialtyId = internal_ });
        Assert.Equal(HttpStatusCode.BadRequest, selfCopy);
        Assert.Equal(ErrorCodes.InvalidValue, selfCopyBody.FieldCode("fromSpecialtyId"));
        Assert.True(await TestData.WithDbAsync(Factory, db => db.AuditLogs.AnyAsync(a => a.Action == "specialtyProfileUpdated" && a.TargetId == internal_.ToString())));

        // The General profile never shows at sign-up.
        var (_, signup) = await Factory.Client().GetJsonAsync("/api/specialties");
        Assert.DoesNotContain(signup.EnumerateArray(), s => s.Str("nameEn") == "General");
    }

    [Fact]
    public async Task The_seed_command_loads_the_builders_profiles_and_refuses_unknown_names()
    {
        var csv = Path.Combine(Path.GetTempPath(), $"profiles-{Guid.NewGuid():N}.csv");
        await File.WriteAllTextAsync(csv, "﻿specialty_name_en,item_type,value\nDermatology,drugGroup,topical-steroids\nDermatology,drugGroup,anti-acne\n\"Dermatology\",labCode,\"58410-2\"\nGeneral,drugGroup,analgesics\n");
        var bad = Path.Combine(Path.GetTempPath(), $"profiles-{Guid.NewGuid():N}.csv");
        await File.WriteAllTextAsync(bad, "specialty_name_en,item_type,value\nDermatology,drugGroup,anti-fungals\nVeterinary,drugGroup,x\nDermatology,colour,green\n");
        try
        {
            await using var scope = Factory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<El3yada.Data.AppDbContext>();
            var output = new StringWriter();

            Assert.Equal(0, await SeedSpecialtyProfilesCommand.ExecuteAsync(db, ["seed-specialty-profiles", csv], output));
            Assert.Equal(0, await SeedSpecialtyProfilesCommand.ExecuteAsync(db, ["seed-specialty-profiles", csv], output));
            var items = await db.SpecialtyProfileItems.AsNoTracking()
                .Where(i => i.Specialty.NameEn == "Dermatology").Select(i => i.ItemType + ":" + i.Value).ToListAsync();
            Assert.Equal(["drugGroup:anti-acne", "drugGroup:topical-steroids", "labCode:58410-2"], items.Order());

            var refused = new StringWriter();
            Assert.Equal(1, await SeedSpecialtyProfilesCommand.ExecuteAsync(db, ["seed-specialty-profiles", bad], refused));
            Assert.Contains("Veterinary", refused.ToString());
            Assert.Contains("colour", refused.ToString());
            Assert.Equal(3, await db.SpecialtyProfileItems.CountAsync(i => i.Specialty.NameEn == "Dermatology"));
            Assert.Equal(2, await SeedSpecialtyProfilesCommand.ExecuteAsync(db, ["seed-specialty-profiles"], refused));
        }
        finally
        {
            File.Delete(csv);
            File.Delete(bad);
        }
    }

    private static byte[] Compress(byte[] bytes)
    {
        using var output = new MemoryStream();
        using (var gzip = new GZipStream(output, CompressionLevel.Fastest, leaveOpen: true))
        {
            gzip.Write(bytes);
        }

        return output.ToArray();
    }
}

internal static class HttpPutExtensions
{
    public static async Task<(HttpStatusCode Status, JsonElement Body)> PutAsync(this HttpClient client, string url, object body)
    {
        using var response = await client.PutAsJsonAsync(url, body);
        return (response.StatusCode, await Http.BodyAsync(response));
    }
}
