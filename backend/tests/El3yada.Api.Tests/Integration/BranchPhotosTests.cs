using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Controllers;
using Microsoft.EntityFrameworkCore;
using SkiaSharp;

namespace El3yada.Api.Tests.Integration;

/// <summary>D29 branch photos [S] (BR-BR2, up to 5) and P3, where the doctor's linked patients see them.</summary>
[Collection(IntegrationCollection.Name)]
public sealed class BranchPhotosTests(IntegrationHost host)
{
    private IntegrationFactory Factory => host.Factory;

    private static async Task<(HttpStatusCode Status, JsonElement Body)> UploadAsync(
        HttpClient client, Guid branchId, byte[] bytes, string contentType = "image/jpeg", string name = "photo.jpg")
    {
        using var form = new MultipartFormDataContent { { new StringContent(branchId.ToString()), "branchId" } };
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue(contentType);
        form.Add(file, "file", name);
        using var response = await client.PostAsync("/api/branches/uploadBranchPhoto", form);
        return (response.StatusCode, await Http.BodyAsync(response));
    }

    private static List<Guid> PhotoIds(JsonElement details) =>
        details.GetProperty("photos").EnumerateArray().Select(p => p.GetProperty("id").GetGuid()).ToList();

    [Fact]
    public async Task The_doctor_adds_photos_that_are_cut_to_1600_px_with_a_thumbnail_up_to_five()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await UploadAsync(client, branch, TestImages.Encode(3000, 1500, SKEncodedImageFormat.Jpeg));
        Assert.Equal(HttpStatusCode.Created, status);
        var first = Assert.Single(PhotoIds(body));

        // Stored as a JPEG of at most 1600 px on the long edge, and a small thumbnail.
        using var photo = await client.GetAsync($"/api/branches/{branch}/photos/{first}");
        Assert.Equal(HttpStatusCode.OK, photo.StatusCode);
        Assert.Equal("image/jpeg", photo.Content.Headers.ContentType!.MediaType);
        using (var bitmap = SKBitmap.Decode(await photo.Content.ReadAsByteArrayAsync()))
        {
            Assert.Equal((1600, 800), (bitmap.Width, bitmap.Height));
        }

        using var thumb = await client.GetAsync($"/api/branches/{branch}/photos/{first}?thumb=true");
        Assert.Equal(HttpStatusCode.OK, thumb.StatusCode);
        using (var bitmap = SKBitmap.Decode(await thumb.Content.ReadAsByteArrayAsync()))
        {
            Assert.True(Math.Max(bitmap.Width, bitmap.Height) <= 320);
        }

        // PNG and WebP are accepted too, and come back as JPEG. Five is the most.
        Assert.Equal(HttpStatusCode.Created, (await UploadAsync(client, branch, TestImages.Encode(40, 30, SKEncodedImageFormat.Png), "image/png", "a.png")).Status);
        Assert.Equal(HttpStatusCode.Created, (await UploadAsync(client, branch, TestImages.Encode(40, 30, SKEncodedImageFormat.Webp), "image/webp", "a.webp")).Status);
        for (var i = 0; i < 2; i++)
        {
            Assert.Equal(HttpStatusCode.Created, (await UploadAsync(client, branch, TestImages.Encode(40, 30, SKEncodedImageFormat.Jpeg))).Status);
        }

        (status, body) = await UploadAsync(client, branch, TestImages.Encode(40, 30, SKEncodedImageFormat.Jpeg));
        Assert.Equal(HttpStatusCode.Conflict, status);
        Assert.Equal(ErrorCodes.BranchPhotoLimit, body.Code());
        Assert.Equal(BranchPhotosController.MaxPhotos, await TestData.WithDbAsync(Factory, db => db.BranchPhotos.CountAsync(p => p.BranchId == branch)));
        Assert.Equal(5, (await TestData.ClinicAuditAsync(Factory, doctor.Id, AuditActions.BranchPhotosUpdated)).Count);

        // The D29 view lists them in order.
        var (_, details) = await client.GetJsonAsync($"/api/branches/{branch}");
        Assert.Equal(5, PhotoIds(details).Count);
        Assert.Equal(first, PhotoIds(details)[0]);
    }

    [Fact]
    public async Task Only_images_are_accepted()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);

        var (status, body) = await UploadAsync(client, branch, Encoding.ASCII.GetBytes("%PDF-1.7\n%%EOF\n"), "application/pdf", "menu.pdf");
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, body.FieldCode("file"));

        // A renamed text file is refused by its bytes, whatever it claims.
        (status, body) = await UploadAsync(client, branch, Encoding.ASCII.GetBytes("not really a photo, just text"), "image/jpeg");
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.FileTypeNotAllowed, body.FieldCode("file"));

        using var empty = new MultipartFormDataContent { { new StringContent(branch.ToString()), "branchId" } };
        using var missing = await client.PostAsync("/api/branches/uploadBranchPhoto", empty);
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        Assert.Equal(0, await TestData.WithDbAsync(Factory, db => db.BranchPhotos.CountAsync(p => p.BranchId == branch)));
    }

    [Fact]
    public async Task Photos_are_reordered_and_deleted_with_their_files()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var client = await Factory.SignedInClientAsync(doctor);
        for (var i = 0; i < 3; i++) await UploadAsync(client, branch, TestImages.Encode(20 + i, 20, SKEncodedImageFormat.Jpeg));
        var (_, details) = await client.GetJsonAsync($"/api/branches/{branch}");
        var ids = PhotoIds(details);

        var (status, body) = await client.PostAsync("/api/branches/reorderBranchPhotos", new { branchId = branch, photoIds = new[] { ids[2], ids[0], ids[1] } });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal([ids[2], ids[0], ids[1]], PhotoIds(body));

        // Every photo, once each.
        (status, body) = await client.PostAsync("/api/branches/reorderBranchPhotos", new { branchId = branch, photoIds = new[] { ids[0], ids[0], ids[1] } });
        Assert.Equal(HttpStatusCode.BadRequest, status);
        Assert.Equal(ErrorCodes.InvalidValue, body.FieldCode("photoIds"));

        var path = await TestData.WithDbAsync(Factory, db => db.BranchPhotos.Where(p => p.Id == ids[0]).Select(p => p.Path).SingleAsync());
        Assert.True(File.Exists(Path.Combine(Factory.FilesDirectory, path)));
        (status, body) = await client.PostAsync("/api/branches/deleteBranchPhoto", new { branchId = branch, photoId = ids[0] });
        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal([ids[2], ids[1]], PhotoIds(body));
        Assert.False(File.Exists(Path.Combine(Factory.FilesDirectory, path)));
        Assert.False(File.Exists(Path.Combine(Factory.FilesDirectory, path.Replace(".jpg", ".thumb.jpg"))));
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/branches/{branch}/photos/{ids[0]}")).StatusCode);
    }

    [Fact]
    public async Task Another_doctors_branch_is_not_found_and_assistants_only_read()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        var other = await TestData.CreateDoctorAsync(Factory);
        using var doctorClient = await Factory.SignedInClientAsync(doctor);
        var (_, uploaded) = await UploadAsync(doctorClient, branch, TestImages.Encode(20, 20, SKEncodedImageFormat.Jpeg));
        var photo = Assert.Single(PhotoIds(uploaded));

        // Another clinic: nothing to find, to read, to order or to delete.
        using var otherClient = await Factory.SignedInClientAsync(other);
        var (status, body) = await UploadAsync(otherClient, branch, TestImages.Encode(20, 20, SKEncodedImageFormat.Jpeg));
        Assert.Equal(HttpStatusCode.NotFound, status);
        Assert.Equal(ErrorCodes.NotFound, body.Code());
        Assert.Equal(HttpStatusCode.NotFound, (await otherClient.GetAsync($"/api/branches/{branch}/photos/{photo}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await otherClient.PostAsync("/api/branches/deleteBranchPhoto", new { branchId = branch, photoId = photo })).Status);
        Assert.Equal(HttpStatusCode.NotFound, (await otherClient.PostAsync("/api/branches/reorderBranchPhotos", new { branchId = branch, photoIds = new[] { photo } })).Status);

        // Assistants read them; adding, ordering and deleting are the doctor's (BR-AS5, AS17's Info tab is read-only),
        // with or without scheduleManage.
        var reception = await TestData.CreateAssistantWithPresetAsync(Factory, doctor.Id, "reception");
        var scheduler = await TestData.CreateAssistantAsync(
            Factory, doctor.Id, permissions: ClinicPermissions.WithDependencies([ClinicPermissions.ScheduleManage]));
        foreach (var assistant in new[] { reception, scheduler })
        {
            using var client = await Factory.SignedInClientAsync(assistant);
            (status, body) = await UploadAsync(client, branch, TestImages.Encode(20, 20, SKEncodedImageFormat.Jpeg));
            Assert.Equal(HttpStatusCode.Forbidden, status);
            Assert.Equal(ErrorCodes.PermissionDenied, body.Code());
            Assert.Equal("doctorOnly", body.Str("permission"));
            (status, _) = await client.PostAsync("/api/branches/deleteBranchPhoto", new { branchId = branch, photoId = photo });
            Assert.Equal(HttpStatusCode.Forbidden, status);
            Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/branches/{branch}/photos/{photo}?thumb=true")).StatusCode);
        }

        Assert.Single(await TestData.WithDbAsync(Factory, db => db.BranchPhotos.Where(p => p.BranchId == branch).ToListAsync()));
    }

    [Fact]
    public async Task Linked_patients_see_the_photos_in_P3_and_others_do_not()
    {
        var doctor = await TestData.CreateDoctorAsync(Factory);
        var branch = await TestData.DefaultBranchAsync(Factory, doctor.Id);
        using var doctorClient = await Factory.SignedInClientAsync(doctor);
        await UploadAsync(doctorClient, branch, TestImages.Encode(20, 20, SKEncodedImageFormat.Jpeg));
        var (_, second) = await UploadAsync(doctorClient, branch, TestImages.Encode(30, 20, SKEncodedImageFormat.Jpeg));
        var ids = PhotoIds(second);
        var (linkedUser, linkedPatient) = await TestData.CreatePatientAsync(Factory);
        await TestData.LinkAsync(Factory, doctor.Id, linkedPatient);
        var (strangerUser, _) = await TestData.CreatePatientAsync(Factory);

        using var linked = await Factory.SignedInClientAsync(linkedUser);
        var (status, info) = await linked.GetJsonAsync($"/api/patient/doctors/{doctor.Id}");
        Assert.Equal(HttpStatusCode.OK, status);
        var card = info.GetProperty("branches").EnumerateArray().Single(b => b.GetProperty("id").GetGuid() == branch);
        Assert.Equal(ids, card.GetProperty("photoIds").EnumerateArray().Select(p => p.GetGuid()));
        using var thumb = await linked.GetAsync($"/api/patient/doctors/{doctor.Id}/branches/{branch}/photos/{ids[1]}?thumb=true");
        Assert.Equal(HttpStatusCode.OK, thumb.StatusCode);
        Assert.Equal("image/jpeg", thumb.Content.Headers.ContentType!.MediaType);

        using var stranger = await Factory.SignedInClientAsync(strangerUser);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/patient/doctors/{doctor.Id}/branches/{branch}/photos/{ids[1]}")).StatusCode);
        // Only patients use the patient address.
        Assert.Equal(HttpStatusCode.Forbidden, (await doctorClient.GetAsync($"/api/patient/doctors/{doctor.Id}/branches/{branch}/photos/{ids[1]}")).StatusCode);
    }
}
