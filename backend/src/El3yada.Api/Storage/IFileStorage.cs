namespace El3yada.Api.Storage;

/// <summary>
/// The private file store behind the API. Files are never served as public URLs: download endpoints
/// check access first, then stream the file from here.
/// </summary>
public interface IFileStorage
{
    /// <summary>
    /// Saves <paramref name="content"/> at <paramref name="path"/>, replacing any file already there.
    /// The content type must match the path, and the first bytes must match the content type.
    /// Stops with <see cref="ErrorCodes.FileTooLarge"/> past <paramref name="maxBytes"/>
    /// (for example AppSettings.MaxUploadMb, or 10 MB for payment screenshots) or Storage:MaxUploadMb,
    /// whichever is smaller. A refused file leaves nothing behind.
    /// </summary>
    Task<StoredFile> SaveAsync(
        StoragePath path, Stream content, string contentType, long? maxBytes = null,
        CancellationToken cancellationToken = default);

    /// <summary>Opens a stored file for reading, or returns null if there is none. The caller disposes the stream.</summary>
    Task<StoredFileContent?> OpenReadAsync(StoragePath path, CancellationToken cancellationToken = default);

    /// <summary>Deletes a stored file. Returns false if there was none.</summary>
    Task<bool> DeleteAsync(StoragePath path, CancellationToken cancellationToken = default);

    /// <summary>
    /// Makes a JPEG thumbnail of a stored JPEG, PNG or WebP image and saves it at <paramref name="thumbnail"/>
    /// (a .jpg path). The longest edge is Storage:ThumbnailMaxPx (never enlarged), the EXIF orientation is
    /// applied, transparency becomes white, and metadata (EXIF, GPS) is dropped.
    /// </summary>
    Task<StoredFile> CreateThumbnailAsync(
        StoragePath image, StoragePath thumbnail, CancellationToken cancellationToken = default);

    /// <summary>
    /// The same thumbnail, made from an image that is not stored (the first page of a PDF, rendered by the app).
    /// Throws <see cref="FileStorageException"/> with FILE_CONTENT_INVALID when it is not a readable image.
    /// </summary>
    Task<StoredFile> SaveThumbnailAsync(Stream image, StoragePath thumbnail, CancellationToken cancellationToken = default);

    /// <summary>Moves a stored file to another path of the same type, replacing any file there. False when there was none.</summary>
    Task<bool> MoveAsync(StoragePath from, StoragePath to, CancellationToken cancellationToken = default);
}

public sealed record StoredFile(StoragePath Path, string ContentType, long SizeBytes);

/// <summary>An open stored file. Dispose <see cref="Content"/> (FileStreamResult does it for you).</summary>
public sealed record StoredFileContent(Stream Content, string ContentType, long SizeBytes);
