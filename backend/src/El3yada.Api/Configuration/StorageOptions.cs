using System.ComponentModel.DataAnnotations;

namespace El3yada.Api.Configuration;

/// <summary>File storage settings (section "Storage").</summary>
public sealed class StorageOptions
{
    public const string SectionName = "Storage";

    /// <summary>
    /// Folder that holds every stored file. A relative path is resolved against the API's content root
    /// (Development only). Production needs an absolute path outside the deploy folder (Storage__RootPath).
    /// </summary>
    [Required]
    public string RootPath { get; set; } = "";

    /// <summary>
    /// Hard ceiling for one file, in MB. The admin's per-file limit (AppSettings.MaxUploadMb, 1–200, default 50)
    /// applies below it, so this is the top of that range.
    /// </summary>
    [Range(1, 200)]
    public int MaxUploadMb { get; set; } = 200;

    /// <summary>Longest edge of a generated thumbnail, in pixels.</summary>
    [Range(64, 1024)]
    public int ThumbnailMaxPx { get; set; } = 320;
}
