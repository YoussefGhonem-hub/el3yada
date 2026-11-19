using El3yada.Api.Infrastructure.Errors;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Infrastructure.Files;

public static class FileResults
{
    /// <summary>Streams a stored file. Medical content is never cached and never sniffed as another type.</summary>
    public static async Task<IActionResult> StreamAsync(ControllerBase controller, IFileStorage storage, string path, string mimeType, string fileName, CancellationToken ct)
    {
        var stream = await storage.OpenReadAsync(path, ct) ?? throw ApiException.NotFound(ErrorCodes.FileMissing);
        controller.Response.Headers.CacheControl = "private, no-store";
        controller.Response.Headers.XContentTypeOptions = "nosniff";
        return controller.File(stream, mimeType, fileName, enableRangeProcessing: true);
    }
}
