using System.Buffers;
using El3yada.Api.Configuration;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Storage;

/// <summary>
/// <see cref="IFileStorage"/> on a local or mounted folder (Storage:RootPath). The folder must not be
/// served by a web server; only the API reads it.
/// </summary>
public sealed class LocalFileStorage : IFileStorage
{
    private const int BufferSize = 81920;

    private static readonly StringComparison PathComparison =
        OperatingSystem.IsWindows() || OperatingSystem.IsMacOS() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

    private readonly string _root;
    private readonly long _maxBytes;
    private readonly int _thumbnailMaxPx;

    public LocalFileStorage(IOptions<StorageOptions> options, IHostEnvironment environment)
    {
        var settings = options.Value;
        _root = Path.TrimEndingDirectorySeparator(Path.GetFullPath(settings.RootPath, environment.ContentRootPath))
            + Path.DirectorySeparatorChar;
        _maxBytes = settings.MaxUploadMb * 1024L * 1024L;
        _thumbnailMaxPx = settings.ThumbnailMaxPx;
    }

    public async Task<StoredFile> SaveAsync(
        StoragePath path, Stream content, string contentType, long? maxBytes = null,
        CancellationToken cancellationToken = default)
    {
        var type = FileTypes.Normalize(contentType)
            ?? throw new FileStorageException(ErrorCodes.FileTypeNotAllowed, "Only JPEG, PNG, WebP and PDF files are accepted.");
        if (type != path.ContentType)
        {
            throw new ArgumentException($"The content type {type} does not match the path {path}.", nameof(contentType));
        }

        if (maxBytes is <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxBytes));
        }

        var limit = Math.Min(maxBytes ?? _maxBytes, _maxBytes);
        if (content.CanSeek && content.Length - content.Position > limit)
        {
            throw TooLarge();
        }

        var fullPath = FullPathOf(path);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);

        // Write next to the target, then rename, so a reader never sees half a file.
        var tempPath = $"{fullPath}.{Guid.NewGuid():N}.tmp";
        var buffer = ArrayPool<byte>.Shared.Rent(BufferSize);
        try
        {
            long size;
            await using (var output = new FileStream(
                tempPath, FileMode.CreateNew, FileAccess.Write, FileShare.None, BufferSize, FileOptions.Asynchronous))
            {
                var headerLength = await content.ReadAtLeastAsync(
                    buffer.AsMemory(0, FileTypes.SignatureLength), FileTypes.SignatureLength,
                    throwOnEndOfStream: false, cancellationToken);
                if (!FileTypes.HasSignature(type, buffer.AsSpan(0, headerLength)))
                {
                    throw new FileStorageException(ErrorCodes.FileContentInvalid, "The file content does not match its type.");
                }

                size = 0;
                var read = headerLength;
                do
                {
                    size += read;
                    if (size > limit)
                    {
                        throw TooLarge();
                    }

                    await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                }
                while ((read = await content.ReadAsync(buffer.AsMemory(0, BufferSize), cancellationToken)) > 0);
            }

            File.Move(tempPath, fullPath, overwrite: true);
            return new StoredFile(path, type, size);
        }
        catch
        {
            TryDelete(tempPath);
            throw;
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer);
        }
    }

    public Task<StoredFileContent?> OpenReadAsync(StoragePath path, CancellationToken cancellationToken = default)
    {
        try
        {
            // FileShare.Delete lets a save replace (or a delete remove) a file that is being downloaded.
            var stream = new FileStream(
                FullPathOf(path), FileMode.Open, FileAccess.Read, FileShare.Read | FileShare.Delete,
                BufferSize, FileOptions.Asynchronous | FileOptions.SequentialScan);
            return Task.FromResult<StoredFileContent?>(new StoredFileContent(stream, path.ContentType, stream.Length));
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException)
        {
            return Task.FromResult<StoredFileContent?>(null);
        }
    }

    public Task<bool> DeleteAsync(StoragePath path, CancellationToken cancellationToken = default)
    {
        var fullPath = FullPathOf(path);
        if (!File.Exists(fullPath))
        {
            return Task.FromResult(false);
        }

        File.Delete(fullPath);
        return Task.FromResult(true);
    }

    public async Task<StoredFile> CreateThumbnailAsync(
        StoragePath image, StoragePath thumbnail, CancellationToken cancellationToken = default)
    {
        if (!FileTypes.IsImage(image.ContentType))
        {
            throw new ArgumentException("Thumbnails are made from JPEG, PNG or WebP images.", nameof(image));
        }

        if (thumbnail.ContentType != FileTypes.Jpeg)
        {
            throw new ArgumentException("A thumbnail path ends in .jpg.", nameof(thumbnail));
        }

        byte[] jpeg;
        await using (var source = new FileStream(
            FullPathOf(image), FileMode.Open, FileAccess.Read, FileShare.Read | FileShare.Delete,
            BufferSize, FileOptions.SequentialScan))
        {
            jpeg = Thumbnailer.CreateJpeg(source, _thumbnailMaxPx);
        }

        using var content = new MemoryStream(jpeg, writable: false);
        return await SaveAsync(thumbnail, content, FileTypes.Jpeg, cancellationToken: cancellationToken);
    }

    /// <summary>
    /// The full path of a stored file. <see cref="StoragePath"/> already rules out "..", rooted paths and
    /// odd characters; this check is a second guard that the result stays inside the root.
    /// </summary>
    private string FullPathOf(StoragePath path)
    {
        var fullPath = Path.GetFullPath(Path.Join(_root, path.Value));
        if (!fullPath.StartsWith(_root, PathComparison))
        {
            throw new InvalidOperationException("A storage path resolved outside the storage root.");
        }

        return fullPath;
    }

    private static FileStorageException TooLarge() =>
        new(ErrorCodes.FileTooLarge, "The file is larger than the upload limit.");

    private static void TryDelete(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (IOException)
        {
            // Best effort: a leftover .tmp file is harmless.
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
