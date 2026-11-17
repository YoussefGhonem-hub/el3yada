using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.Records;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SkiaSharp;

namespace El3yada.Api.Tests.Integration;

/// <summary>
/// Medical files (spec 6.3, D10–D12, AS6, AC-14): upload, optimization for storage, records, downloads,
/// permissions. Contract: backend/docs/api-phase-3-files.md.
/// </summary>
[Collection(IntegrationCollection.Name)]
public sealed class MedicalRecordsTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static async Task<(HttpStatusCode Status, JsonElement Body)> UploadAsync(
        HttpClient client, byte[] bytes, string fileName, string contentType = "application/octet-stream",
        byte[]? thumbnail = null, int? pageCount = null)
    {
        using var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        form.Add(file, "file", fileName);
        if (thumbnail is not null)
        {
            var thumb = new ByteArrayContent(thumbnail);
            thumb.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
            form.Add(thumb, "thumbnail", "thumb.jpg");
        }

        if (pageCount is not null)
        {
            form.Add(new StringContent(pageCount.Value.ToString()), "pageCount");
        }

        using var response = await client.PostAsync("/api/records/uploadFile", form);
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    private static async Task<Guid> UploadIdAsync(HttpClient client, byte[] bytes, string fileName, string contentType = "application/octet-stream")
    {
        var (status, body) = await UploadAsync(client, bytes, fileName, contentType);
        Assert.True(status == HttpStatusCode.Created, $"uploadFile failed: {status} {body}");
        return body.GetProperty("uploadId").GetGuid();
    }

    private static byte[] Pdf => Encoding.ASCII.GetBytes("%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n");

    private static object RecordBody(Guid patientId, IEnumerable<Guid> uploadIds, string category = "lab", object? extra = null)
    {
        var body = new Dictionary<string, object?>
        {
            ["patientId"] = patientId, ["category"] = category, ["source"] = "upload", ["uploadIds"] = uploadIds.ToArray(),
        };
        if (extra is not null)
        {
            foreach (var property in extra.GetType().GetProperties())
            {
                body[char.ToLowerInvariant(property.Name[0]) + property.Name[1..]] = property.GetValue(extra);
            }
        }

        return body;
    }

    [Fact]
    public async Task A_big_photo_is_made_smaller_upright_and_without_location_data()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var photo = TestImages.WithExifOrientation(TestImages.Encode(4000, 3000, SKEncodedImageFormat.Jpeg, halves: true), 6);

        var (status, upload) = await UploadAsync(client, photo, "IMG_2041.JPG");

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("image/jpeg", upload.Str("mimeType"));
        Assert.Equal("IMG_2041.JPG", upload.Str("fileName"));
        Assert.True(upload.GetProperty("optimized").GetBoolean());
        Assert.True(upload.GetProperty("hasThumbnail").GetBoolean());
        Assert.Equal(photo.Length, upload.GetProperty("originalSizeBytes").GetInt64());
        var stored = await TestData.WithDbAsync(Factory, db => db.PendingUploads.SingleAsync(u => u.Id == upload.GetProperty("uploadId").GetGuid()));
        var bytes = await File.ReadAllBytesAsync(Path.Combine(Factory.FilesDirectory, stored.Path));
        using var codec = SKCodec.Create(new MemoryStream(bytes));
        // Turned upright (orientation 6 = a quarter turn) and cut to 2560 px on the long edge.
        Assert.Equal(1920, codec.Info.Width);
        Assert.Equal(2560, codec.Info.Height);
        Assert.Equal(SKEncodedOrigin.TopLeft, codec.EncodedOrigin);
        Assert.Null(JpegMetadataTests.FindSegment(bytes, 0xE1));
        Assert.Equal(bytes.Length, stored.StoredSizeBytes);
        Assert.Equal(stored.SizeBytes, stored.StoredSizeBytes);
        Assert.True(File.Exists(Path.Combine(Factory.FilesDirectory, stored.ThumbPath!)));
    }

    [Fact]
    public async Task A_small_jpeg_keeps_its_pixels_and_loses_only_its_metadata()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var original = TestImages.Encode(800, 600, SKEncodedImageFormat.Jpeg);
        var withExif = TestImages.WithExifOrientation(original, 1);

        var (_, upload) = await UploadAsync(client, withExif, "small.jpg");

        var stored = await TestData.WithDbAsync(Factory, db => db.PendingUploads.SingleAsync(u => u.Id == upload.GetProperty("uploadId").GetGuid()));
        var bytes = await File.ReadAllBytesAsync(Path.Combine(Factory.FilesDirectory, stored.Path));
        Assert.Equal(original, bytes); // the same JPEG, minus the EXIF segment
    }

    [Fact]
    public async Task Records_hold_several_files_in_order_and_the_patient_is_told()
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var sessionId = await TestData.RecordSessionAsync(client, patientId, branchId);
        var xray = await UploadIdAsync(client, TestImages.Encode(1200, 900, SKEncodedImageFormat.Png), "xray.png");
        var (pdfStatus, pdf) = await UploadAsync(client, Pdf, "report.pdf", "application/pdf",
            thumbnail: TestImages.Encode(300, 420, SKEncodedImageFormat.Jpeg), pageCount: 3);
        Assert.Equal(HttpStatusCode.Created, pdfStatus);
        Assert.True(pdf.GetProperty("hasThumbnail").GetBoolean());

        var (status, record) = await client.PostAsync("/api/records/createRecord", RecordBody(
            patientId, [xray, pdf.GetProperty("uploadId").GetGuid()], "radiology", new { sessionId, documentDate = "2026-11-01", notes = "  بعد الحادثة " }));

        Assert.Equal(HttpStatusCode.Created, status);
        Assert.Equal("radiology", record.Str("category"));
        Assert.Equal("أشعة 2026-11-01", record.Str("title"));
        Assert.Equal("بعد الحادثة", record.Str("notes"));
        Assert.Equal(sessionId, record.GetProperty("session").GetProperty("sessionId").GetGuid());
        Assert.Equal("doctor", record.GetProperty("createdBy").Str("role"));
        var attachments = record.GetProperty("attachments").EnumerateArray().ToList();
        // A flat PNG stays a PNG: JPEG would not make it smaller.
        Assert.Equal(["xray.png", "report.pdf"], attachments.Select(a => a.Str("fileName")));
        Assert.Equal(3, attachments[1].GetProperty("pageCount").GetInt32());
        Assert.All(attachments, a => Assert.True(a.GetProperty("previewable").GetBoolean()));
        Assert.All(attachments, a => Assert.True(a.GetProperty("hasThumbnail").GetBoolean()));
        Assert.Equal(attachments.Sum(a => a.GetProperty("sizeBytes").GetInt64()), record.GetProperty("totalSizeBytes").GetInt64());

        // The files moved out of the pending area.
        var recordId = record.GetProperty("recordId").GetGuid();
        Assert.False(await TestData.WithDbAsync(Factory, db => db.PendingUploads.AnyAsync(u => u.DoctorId == doctor.Id)));
        var paths = await TestData.WithDbAsync(Factory, db => db.MedicalRecordAttachments.Where(a => a.RecordId == recordId).Select(a => a.Path).ToListAsync());
        Assert.All(paths, p => Assert.StartsWith($"medical/{doctor.Id}/{patientId}/{recordId}/", p));
        Assert.All(paths, p => Assert.True(File.Exists(Path.Combine(Factory.FilesDirectory, p))));

        // BR-F9 and the activity log.
        var patientUserId = await TestData.WithDbAsync(Factory, db => db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).SingleAsync());
        var notification = await TestData.WithDbAsync(Factory, db => db.Notifications.SingleAsync(n => n.RecipientUserId == patientUserId && n.Type == "recordAdded"));
        Assert.Contains("أشعة", notification.BodyAr);
        Assert.DoesNotContain("الحادثة", notification.BodyAr);
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, "medicalRecordCreated"));
        Assert.Equal(patientId, audit.PatientId);
        Assert.DoesNotContain("xray", audit.DetailsJson);

        // Downloads and the thumbnail.
        var pdfId = attachments[1].GetProperty("attachmentId").GetGuid();
        using var inline = await client.GetAsync($"/api/records/{recordId}/attachments/{pdfId}");
        Assert.Equal(HttpStatusCode.OK, inline.StatusCode);
        Assert.Equal("application/pdf", inline.Content.Headers.ContentType?.MediaType);
        Assert.Equal("inline", inline.Content.Headers.ContentDisposition?.DispositionType);
        Assert.Equal(Pdf, await inline.Content.ReadAsByteArrayAsync());
        using var attached = await client.GetAsync($"/api/records/{recordId}/attachments/{pdfId}?download=true");
        Assert.Equal("attachment", attached.Content.Headers.ContentDisposition?.DispositionType);
        using var thumb = await client.GetAsync($"/api/records/{recordId}/attachments/{pdfId}/thumbnail");
        Assert.Equal(HttpStatusCode.OK, thumb.StatusCode);
        Assert.Equal("image/jpeg", thumb.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task Other_files_are_stored_compressed_when_it_helps_and_come_back_exactly()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var csv = Encoding.UTF8.GetBytes(string.Concat(Enumerable.Repeat("date,test,value\n2026-11-01,HbA1c,6.2\n", 4000)));
        var zip = new byte[64 * 1024];
        Random.Shared.NextBytes(zip);
        zip[0] = 0x50; zip[1] = 0x4B; zip[2] = 0x03; zip[3] = 0x04;

        var (csvStatus, csvUpload) = await UploadAsync(client, csv, "results.csv", "text/csv");
        var (zipStatus, zipUpload) = await UploadAsync(client, zip, "dicom-series.zip", "application/octet-stream");

        Assert.Equal(HttpStatusCode.Created, csvStatus);
        Assert.Equal("text/csv", csvUpload.Str("mimeType"));
        Assert.True(csvUpload.GetProperty("storedSizeBytes").GetInt64() < csv.Length / 10);
        Assert.Equal(csv.Length, csvUpload.GetProperty("sizeBytes").GetInt64());
        Assert.Equal(HttpStatusCode.Created, zipStatus);
        Assert.Equal("application/zip", zipUpload.Str("mimeType"));
        Assert.Equal(zip.Length, zipUpload.GetProperty("storedSizeBytes").GetInt64());
        Assert.False(zipUpload.GetProperty("optimized").GetBoolean());

        var (_, record) = await client.PostAsync("/api/records/createRecord", RecordBody(
            patientId, [csvUpload.GetProperty("uploadId").GetGuid(), zipUpload.GetProperty("uploadId").GetGuid()], "other",
            new { otherType = "custom", otherTypeText = "  نتائج   معمل خارجي " }));
        var recordId = record.GetProperty("recordId").GetGuid();
        var attachments = record.GetProperty("attachments").EnumerateArray().ToList();
        Assert.Equal("نتائج معمل خارجي", record.Str("otherTypeText"));
        Assert.StartsWith("نتائج معمل خارجي ", record.Str("title"));
        Assert.All(attachments, a => Assert.False(a.GetProperty("previewable").GetBoolean()));
        var storedCsv = await TestData.WithDbAsync(Factory, db => db.MedicalRecordAttachments.SingleAsync(a => a.RecordId == recordId && a.SortOrder == 0));
        Assert.EndsWith(".gz", storedCsv.Path);
        await using (var gz = new GZipStream(File.OpenRead(Path.Combine(Factory.FilesDirectory, storedCsv.Path)), CompressionMode.Decompress))
        using (var copy = new MemoryStream())
        {
            await gz.CopyToAsync(copy);
            Assert.Equal(csv, copy.ToArray());
        }

        using var download = await client.GetAsync($"/api/records/{recordId}/attachments/{attachments[0].GetProperty("attachmentId").GetGuid()}?download=true");
        Assert.Equal(HttpStatusCode.OK, download.StatusCode);
        Assert.Equal("text/csv", download.Content.Headers.ContentType?.MediaType);
        Assert.Equal(csv, await download.Content.ReadAsByteArrayAsync());
        Assert.Equal("results.csv", download.Content.Headers.ContentDisposition?.FileNameStar);
        Assert.Contains("nosniff", download.Headers.GetValues("X-Content-Type-Options"));
    }

    [Fact]
    public async Task The_size_limit_is_the_admin_setting_and_counts_the_file_as_uploaded()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var old = await TestData.WithDbAsync(Factory, db => db.AppSettings.Select(s => s.MaxUploadMb).SingleAsync());
        await TestData.WithDbAsync(Factory, db => db.AppSettings.ExecuteUpdateAsync(set => set.SetProperty(s => s.MaxUploadMb, 1)));
        try
        {
            var (status, body) = await UploadAsync(client, new byte[(1024 * 1024) + 1], "big.dcm");
            var (missingStatus, missing) = await UploadAsync(client, [], "empty.txt");

            Assert.Equal(HttpStatusCode.BadRequest, status);
            Assert.Equal(ErrorCodes.FileTooLarge, body.FieldCode("file"));
            Assert.Equal(1, body.GetProperty("maxMb").GetInt32());
            Assert.Equal(HttpStatusCode.BadRequest, missingStatus);
            Assert.Equal(ErrorCodes.Required, missing.FieldCode("file"));
        }
        finally
        {
            await TestData.WithDbAsync(Factory, db => db.AppSettings.ExecuteUpdateAsync(set => set.SetProperty(s => s.MaxUploadMb, old)));
        }
    }

    [Fact]
    public async Task Broken_images_and_thumbnails_are_refused()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        byte[] broken = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3];

        var (imageStatus, image) = await UploadAsync(client, broken, "photo.jpg");
        var (thumbStatus, thumb) = await UploadAsync(client, Pdf, "a.pdf", thumbnail: Encoding.ASCII.GetBytes("not an image at all"));
        var (pagesStatus, pages) = await UploadAsync(client, Pdf, "a.pdf", pageCount: 0);

        Assert.Equal(HttpStatusCode.BadRequest, imageStatus);
        Assert.Equal(ErrorCodes.FileContentInvalid, image.FieldCode("file"));
        Assert.Equal(HttpStatusCode.BadRequest, thumbStatus);
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, thumb.FieldCode("thumbnail"));
        Assert.Equal(HttpStatusCode.BadRequest, pagesStatus);
        Assert.Equal(ErrorCodes.OutOfRange, pages.FieldCode("pageCount"));
    }

    [Fact]
    public async Task CreateRecord_checks_every_field()
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var otherPatient = await TestData.AddPatientViaApiAsync(client);
        var otherSession = await TestData.RecordSessionAsync(client, otherPatient, branchId);
        var (_, otherClient, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var foreignUpload = await UploadIdAsync(otherClient, Pdf, "x.pdf");
        var upload = await UploadIdAsync(client, Pdf, "x.pdf");
        var expired = await UploadIdAsync(client, Pdf, "old.pdf");
        await TestData.WithDbAsync(Factory, db => db.PendingUploads.Where(u => u.Id == expired)
            .ExecuteUpdateAsync(set => set.SetProperty(u => u.ExpiresAt, DateTime.UtcNow.AddMinutes(-1))));

        async Task<JsonElement> Bad(object body)
        {
            var (status, problem) = await client.PostAsync("/api/records/createRecord", body);
            Assert.Equal(HttpStatusCode.BadRequest, status);
            return problem;
        }

        Assert.Equal(ErrorCodes.UploadNotFound, (await Bad(RecordBody(patientId, [foreignUpload]))).FieldCode("uploadIds"));
        var expiredProblem = await Bad(RecordBody(patientId, [upload, expired]));
        Assert.Equal(ErrorCodes.UploadNotFound, expiredProblem.FieldCode("uploadIds"));
        Assert.Equal(expired, expiredProblem.GetProperty("uploadId").GetGuid());
        Assert.Equal(ErrorCodes.TooMany, (await Bad(RecordBody(patientId, Enumerable.Range(0, 21).Select(_ => Guid.NewGuid())))).FieldCode("uploadIds"));
        Assert.Equal(ErrorCodes.Required, (await Bad(RecordBody(patientId, []))).FieldCode("uploadIds"));
        Assert.Equal(ErrorCodes.InvalidSession, (await Bad(RecordBody(patientId, [upload], extra: new { sessionId = otherSession }))).FieldCode("sessionId"));
        Assert.Equal(ErrorCodes.InvalidDate, (await Bad(RecordBody(patientId, [upload], extra: new { documentDate = DateTime.UtcNow.AddDays(3).ToString("yyyy-MM-dd") }))).FieldCode("documentDate"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(RecordBody(patientId, [upload], "lab", new { otherType = "sickLeave" }))).FieldCode("otherType"));
        Assert.Equal(ErrorCodes.Required, (await Bad(RecordBody(patientId, [upload], "other", new { otherType = "custom" }))).FieldCode("otherTypeText"));
        Assert.Equal(ErrorCodes.InvalidValue, (await Bad(RecordBody(patientId, [upload], "xray"))).FieldCode("category"));

        var (notLinkedStatus, _) = await otherClient.PostAsync("/api/records/createRecord", RecordBody(patientId, [foreignUpload]));
        Assert.Equal(HttpStatusCode.NotFound, notLinkedStatus);

        // The upload is still waiting after the refusals.
        var (okStatus, ok) = await client.PostAsync("/api/records/createRecord", RecordBody(patientId, [upload], "other", new { otherType = "sickLeave" }));
        Assert.Equal(HttpStatusCode.Created, okStatus);
        Assert.StartsWith("إجازة مرضية ", ok.Str("title"));
        var (againStatus, again) = await client.PostAsync("/api/records/createRecord", RecordBody(patientId, [upload]));
        Assert.Equal(HttpStatusCode.BadRequest, againStatus);
        Assert.Equal(ErrorCodes.UploadNotFound, again.FieldCode("uploadIds"));
    }

    [Fact]
    public async Task The_files_tab_lists_newest_first_with_counts_and_hides_deleted_records()
    {
        var (_, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        async Task<Guid> Create(string category, string date)
        {
            var upload = await UploadIdAsync(client, Pdf, "f.pdf");
            var (_, record) = await client.PostAsync("/api/records/createRecord", RecordBody(patientId, [upload], category, new { documentDate = date }));
            return record.GetProperty("recordId").GetGuid();
        }

        var oldLab = await Create("lab", "2026-01-10");
        var newLab = await Create("lab", "2026-11-10");
        var xray = await Create("radiology", "2026-06-01");
        var deleted = await Create("prescription", "2026-11-11");
        var (deleteStatus, _) = await client.PostAsync("/api/records/deleteRecord", new { recordId = deleted });

        var (status, page) = await client.GetJsonAsync($"/api/patients/{patientId}/records");
        var (_, labs) = await client.GetJsonAsync($"/api/patients/{patientId}/records?category=lab");
        var (goneStatus, _) = await client.GetJsonAsync($"/api/records/{deleted}");
        var (againStatus, _) = await client.PostAsync("/api/records/deleteRecord", new { recordId = deleted });

        Assert.Equal(HttpStatusCode.NoContent, deleteStatus);
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal([newLab, xray, oldLab], page.GetProperty("items").EnumerateArray().Select(r => r.GetProperty("recordId").GetGuid()));
        Assert.Equal(3, page.GetProperty("totalCount").GetInt32());
        var counts = page.GetProperty("counts");
        Assert.Equal(2, counts.GetProperty("lab").GetInt32());
        Assert.Equal(1, counts.GetProperty("radiology").GetInt32());
        Assert.Equal(0, counts.GetProperty("prescription").GetInt32());
        Assert.Equal([newLab, oldLab], labs.GetProperty("items").EnumerateArray().Select(r => r.GetProperty("recordId").GetGuid()));
        Assert.Equal(HttpStatusCode.NotFound, goneStatus);
        Assert.Equal(HttpStatusCode.NotFound, againStatus);
        // Soft delete: the row and its files stay.
        Assert.True(await TestData.WithDbAsync(Factory, db => db.MedicalRecords.AnyAsync(r => r.Id == deleted && r.Deleted && r.DeletedBy != null)));
    }

    [Fact]
    public async Task UpdateRecord_replaces_the_details_and_logs_the_changed_fields()
    {
        var (doctor, client, branchId) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var sessionId = await TestData.RecordSessionAsync(client, patientId, branchId);
        var upload = await UploadIdAsync(client, Pdf, "f.pdf");
        var (_, record) = await client.PostAsync("/api/records/createRecord", RecordBody(
            patientId, [upload], "other", new { otherType = "referral", sessionId, notes = "ملاحظة" }));
        var recordId = record.GetProperty("recordId").GetGuid();

        var (status, updated) = await client.PostAsync("/api/records/updateRecord", new
        {
            recordId, category = "lab", otherType = (string?)null, title = "تحليل دم", documentDate = "2026-10-05",
        });

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("lab", updated.Str("category"));
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("otherType").ValueKind);
        Assert.Equal("تحليل دم", updated.Str("title"));
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("notes").ValueKind);
        Assert.Equal(JsonValueKind.Null, updated.GetProperty("session").ValueKind);
        var audit = Assert.Single(await TestData.ClinicAuditAsync(Factory, doctor.Id, "medicalRecordUpdated"));
        var fields = JsonDocument.Parse(audit.DetailsJson!).RootElement.GetProperty("fields").EnumerateArray().Select(f => f.GetString()).ToList();
        Assert.Equal(["category", "otherType", "title", "documentDate", "notes", "sessionId"], fields);
    }

    [Fact]
    public async Task Assistants_need_filesManage_and_never_delete()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        using var asDoctor = await Factory.SignedInClientAsync(doctor);
        var patientId = await TestData.AddPatientViaApiAsync(asDoctor);
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, AssistantPresets.Reception);
        var noFiles = await TestData.CreateAssistantAsync(Factory, doctor.Id, permissions: [ClinicPermissions.PatientsManage]);
        using var asReception = await Factory.SignedInClientAsync(reception);
        using var asNoFiles = await Factory.SignedInClientAsync(noFiles);

        var upload = await UploadIdAsync(asReception, Pdf, "scan.pdf", "application/pdf");
        var (createStatus, record) = await asReception.PostAsync("/api/records/createRecord", RecordBody(patientId, [upload], "lab", new { source = "scan" }));
        var recordId = record.GetProperty("recordId").GetGuid();
        var (listStatus, _) = await asReception.GetJsonAsync($"/api/patients/{patientId}/records");
        var (deleteStatus, delete) = await asReception.PostAsync("/api/records/deleteRecord", new { recordId });
        var (blockedUpload, blocked) = await UploadAsync(asNoFiles, Pdf, "x.pdf");
        var (blockedList, _) = await asNoFiles.GetJsonAsync($"/api/patients/{patientId}/records");

        Assert.Equal(HttpStatusCode.Created, createStatus);
        Assert.Equal("assistant", record.GetProperty("createdBy").Str("role"));
        Assert.Equal("سارة محمود", record.GetProperty("createdBy").Str("name"));
        Assert.Equal("scan", record.Str("source"));
        Assert.Equal(HttpStatusCode.OK, listStatus);
        Assert.Equal(HttpStatusCode.Forbidden, deleteStatus);
        Assert.Equal("doctorOnly", delete.Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, blockedUpload);
        Assert.Equal(ClinicPermissions.FilesManage, blocked.Str("permission"));
        Assert.Equal(HttpStatusCode.Forbidden, blockedList);
    }

    [Fact]
    public async Task Another_clinic_sees_nothing_and_a_suspended_clinic_reads_only()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var patientId = await TestData.AddPatientViaApiAsync(client);
        var upload = await UploadIdAsync(client, Pdf, "f.pdf");
        var (_, record) = await client.PostAsync("/api/records/createRecord", RecordBody(patientId, [upload]));
        var recordId = record.GetProperty("recordId").GetGuid();
        var attachmentId = record.GetProperty("attachments")[0].GetProperty("attachmentId").GetGuid();
        var (_, other, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);

        var (getStatus, _) = await other.GetJsonAsync($"/api/records/{recordId}");
        using var file = await other.GetAsync($"/api/records/{recordId}/attachments/{attachmentId}");
        var (listStatus, _) = await other.GetJsonAsync($"/api/patients/{patientId}/records");
        var (updateStatus, _) = await other.PostAsync("/api/records/updateRecord", new { recordId, category = "lab", documentDate = "2026-11-01" });
        Assert.Equal(HttpStatusCode.NotFound, getStatus);
        Assert.Equal(HttpStatusCode.NotFound, file.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, listStatus);
        Assert.Equal(HttpStatusCode.NotFound, updateStatus);

        await TestData.SetDoctorStatusAsync(Factory, doctor.Id, DoctorStatuses.Suspended);
        var (suspendedUpload, suspended) = await UploadAsync(client, Pdf, "f.pdf");
        var (readStatus, _) = await client.GetJsonAsync($"/api/records/{recordId}");
        Assert.Equal(HttpStatusCode.Forbidden, suspendedUpload);
        Assert.Equal(ErrorCodes.DoctorSuspended, suspended.Code());
        Assert.Equal(HttpStatusCode.OK, readStatus);
    }

    [Fact]
    public async Task Unclaimed_uploads_are_deleted_with_their_files()
    {
        var (doctor, client, _) = await TestData.SignedInDoctorWithBranchAsync(Factory);
        var upload = await UploadIdAsync(client, TestImages.Encode(600, 400, SKEncodedImageFormat.Png), "x.png");
        var row = await TestData.WithDbAsync(Factory, db => db.PendingUploads.SingleAsync(u => u.Id == upload));
        await TestData.WithDbAsync(Factory, db => db.PendingUploads.Where(u => u.Id == upload)
            .ExecuteUpdateAsync(set => set.SetProperty(u => u.ExpiresAt, DateTime.UtcNow.AddSeconds(-1))));

        var deleted = await Factory.Services.GetRequiredService<PendingUploadCleanup>().RunOnceAsync(CancellationToken.None);

        Assert.True(deleted >= 1);
        Assert.False(await TestData.WithDbAsync(Factory, db => db.PendingUploads.AnyAsync(u => u.Id == upload)));
        Assert.False(File.Exists(Path.Combine(Factory.FilesDirectory, row.Path)));
        Assert.False(File.Exists(Path.Combine(Factory.FilesDirectory, row.ThumbPath!)));
    }
}
