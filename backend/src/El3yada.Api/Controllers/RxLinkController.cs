using El3yada.Api.Configuration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Controllers;

/// <summary>
/// spec 9.1 <c>rxLink</c> and 6.4.1 "QR code": <c>GET /rx/{shortCode}</c> is the address printed in every
/// prescription's QR code. On a phone with the app, Android App Links and iOS Universal Links (the two files below)
/// open the app directly, which shows the prescription after sign-in (P7, Phase 4). Without the app, this endpoint
/// runs and sends the browser to the store for the platform, or to the web page on desktop. It never reads the
/// database: the answer is the same for every code, so a code reveals nothing.
/// </summary>
[ApiController]
[AllowAnonymous]
public sealed class RxLinkController(IOptions<AppLinksOptions> options) : ControllerBase
{
    [HttpGet("/rx/{shortCode}")]
    public IActionResult Open(string shortCode)
    {
        var links = options.Value;
        var agent = Request.Headers.UserAgent.ToString();
        var target = agent.Contains("Android", StringComparison.OrdinalIgnoreCase) ? links.PlayStoreUrl
            : agent.Contains("iPhone", StringComparison.OrdinalIgnoreCase) || agent.Contains("iPad", StringComparison.OrdinalIgnoreCase)
                || agent.Contains("iPod", StringComparison.OrdinalIgnoreCase) ? links.AppStoreUrl
            : links.WebUrl;
        Response.Headers.CacheControl = "no-store";
        Response.Headers["Referrer-Policy"] = "no-referrer";
        return Redirect(target);
    }

    /// <summary>Android App Links: which apps may open https://…/rx/* links.</summary>
    [HttpGet("/.well-known/assetlinks.json")]
    public IActionResult AssetLinks()
    {
        var statements = options.Value.Android
            .Where(app => app.Sha256CertFingerprints.Count > 0)
            .Select(app => new
            {
                relation = new[] { "delegate_permission/common.handle_all_urls" },
                target = new { @namespace = "android_app", package_name = app.PackageName, sha256_cert_fingerprints = app.Sha256CertFingerprints },
            });
        return new JsonResult(statements);
    }

    /// <summary>iOS Universal Links: the apps that may open /rx/* links.</summary>
    [HttpGet("/.well-known/apple-app-site-association")]
    public IActionResult AppleAppSiteAssociation() => new JsonResult(new
    {
        applinks = new
        {
            details = options.Value.IosAppIds.Count == 0
                ? []
                : new[] { new { appIDs = options.Value.IosAppIds, components = new[] { new Dictionary<string, string> { ["/"] = "/rx/*" } } } },
        },
    })
    { ContentType = "application/json" };
}
