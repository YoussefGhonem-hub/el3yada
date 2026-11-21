using El3yada.Api.Storage;

namespace El3yada.Api.Infrastructure.Files;

/// <summary>
/// The string-path view of the private file store, for the services that keep a stored path as text
/// (chat attachments, the demo data). It is a thin layer over <see cref="Storage.IFileStorage"/>: the path must be
/// a valid <see cref="StoragePath"/> (built from IDs, never from a file name), the content type is the one the path's
/// extension stands for, and the first bytes must match it.
/// </summary>
public interface IFileStorage
{
    /// <summary>Opens a stored file, or returns null when it doesn't exist.</summary>
    Task<Stream?> OpenReadAsync(string path, CancellationToken ct);

    Task SaveAsync(string path, Stream content, CancellationToken ct);
}

public sealed class FileStorageAdapter(Storage.IFileStorage storage) : IFileStorage
{
    public async Task<Stream?> OpenReadAsync(string path, CancellationToken ct) =>
        (await storage.OpenReadAsync(StoragePath.Parse(path), ct))?.Content;

    public async Task SaveAsync(string path, Stream content, CancellationToken ct)
    {
        var storagePath = StoragePath.Parse(path);
        await storage.SaveAsync(storagePath, content, storagePath.ContentType, cancellationToken: ct);
    }
}
