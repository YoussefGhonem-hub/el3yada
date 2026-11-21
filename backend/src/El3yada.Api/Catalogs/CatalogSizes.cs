using System.Collections.Concurrent;
using El3yada.Api.Storage;
using El3yada.Data.Entities;

namespace El3yada.Api.Catalogs;

/// <summary>
/// How big each published catalog is once unpacked, so D0 can check the free space before downloading. CatalogVersions
/// has no column for it (adding one would need a migration), so publishing measures it while checking the file, and
/// later reads take it from the stored file's gzip trailer. Files never change once published, so each version is read
/// once per process.
/// </summary>
public sealed class CatalogSizes
{
    private readonly ConcurrentDictionary<int, long> _known = new();

    /// <summary>The size measured when the version was published.</summary>
    public void Remember(int versionNumber, long uncompressedBytes) => _known[versionNumber] = uncompressedBytes;

    /// <summary>The unpacked size of <paramref name="version"/>'s file, or null when the file can't be read.</summary>
    public async Task<long?> GetAsync(IFileStorage storage, CatalogVersion version, CancellationToken cancellationToken)
    {
        if (_known.TryGetValue(version.VersionNumber, out var known))
        {
            return known;
        }

        if (!StoragePath.TryParse(version.StoragePath, out var path) || await storage.OpenReadAsync(path, cancellationToken) is not { } file)
        {
            return null;
        }

        long? size;
        await using (file.Content)
        {
            size = await CatalogFile.UncompressedSizeAsync(file.Content, cancellationToken);
        }

        if (size is { } value)
        {
            _known[version.VersionNumber] = value;
        }

        return size;
    }
}

