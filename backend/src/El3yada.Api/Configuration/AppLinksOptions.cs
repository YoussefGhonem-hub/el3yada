using System.ComponentModel.DataAnnotations;

namespace El3yada.Api.Configuration;

/// <summary>
/// The prescription QR code (spec 6.4.1): <c>{PublicBaseUrl}/rx/{shortCode}</c>, Android App Links and iOS Universal
/// Links files, and the store pages <c>GET /rx/{shortCode}</c> sends people to when the app isn't installed.
/// Section "AppLinks". The defaults suit development; production sets real values (checked at start-up).
/// </summary>
public sealed class AppLinksOptions
{
    public const string SectionName = "AppLinks";

    /// <summary>The API's public address, printed in every QR code. No trailing slash needed.</summary>
    [Required, Url]
    public string PublicBaseUrl { get; set; } = "https://localhost:7001";

    [Required, Url]
    public string PlayStoreUrl { get; set; } = "https://play.google.com/store/apps/details?id=com.el3yada.app";

    [Required, Url]
    public string AppStoreUrl { get; set; } = "https://apps.apple.com/app/el3yada/id0000000000";

    /// <summary>Where a desktop browser goes (no app to open): the product's web page.</summary>
    [Required, Url]
    public string WebUrl { get; set; } = "https://el3yada.app";

    /// <summary>Android apps allowed to open /rx links: the prod and dev flavors and their signing certificates.</summary>
    public List<AndroidAppLink> Android { get; set; } =
    [
        new() { PackageName = "com.el3yada.app", Sha256CertFingerprints = [] },
        new() { PackageName = "com.el3yada.app.dev", Sha256CertFingerprints = [] },
    ];

    /// <summary>iOS app IDs ("TEAMID.bundle.id") allowed to open /rx links.</summary>
    public List<string> IosAppIds { get; set; } = [];

    public string QrUrl(string shortCode) => $"{PublicBaseUrl.TrimEnd('/')}/rx/{shortCode}";
}

public sealed class AndroidAppLink
{
    [Required]
    public string PackageName { get; set; } = "";

    /// <summary>"AB:CD:…" SHA-256 fingerprints of the signing certificates (Play App Signing and upload key).</summary>
    public List<string> Sha256CertFingerprints { get; set; } = [];
}
