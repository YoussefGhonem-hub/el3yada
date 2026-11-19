using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Infrastructure.Files;

/// <summary>
/// Private file storage behind the API (spec 8, "File storage paths"). Files are never public
/// URLs: the app downloads them through authenticated endpoints that check access first.
/// Paths are relative, for example <c>medical/{doctorId}/{patientId}/{recordId}/{fileName}</c>.
/// </summary>
public interface IFileStorage
{
    /// <summary>Opens a stored file, or returns null when it doesn't exist.</summary>
    Task<Stream?> OpenReadAsync(string path, CancellationToken ct);

    Task SaveAsync(string path, Stream content, CancellationToken ct);
}

public sealed class FileStorageOptions
{
    public const string Section = "FileStorage";

    /// <summary>Folder on the server. Relative paths are resolved from the content root.</summary>
    [Required]
    public string RootPath { get; set; } = "storage";
}

/// <summary>Stores files in a folder on the server. Swap for object storage without changing callers.</summary>
public sealed class LocalFileStorage : IFileStorage
{
    private readonly string _root;

    public LocalFileStorage(IOptions<FileStorageOptions> options, IHostEnvironment env)
    {
        _root = Path.GetFullPath(Path.Combine(env.ContentRootPath, options.Value.RootPath));
        Directory.CreateDirectory(_root);
    }

    public Task<Stream?> OpenReadAsync(string path, CancellationToken ct)
    {
        var full = Resolve(path);
        Stream? stream = File.Exists(full)
            ? new FileStream(full, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, useAsync: true)
            : null;
        return Task.FromResult(stream);
    }

    public async Task SaveAsync(string path, Stream content, CancellationToken ct)
    {
        var full = Resolve(path);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        await using var file = new FileStream(full, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true);
        await content.CopyToAsync(file, ct);
    }

    // Stored paths come from the database, but check anyway that none escapes the root.
    private string Resolve(string path)
    {
        var full = Path.GetFullPath(Path.Combine(_root, path.Replace('\\', '/').TrimStart('/')));
        if (!full.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Storage path escapes the storage root.");
        return full;
    }
}
