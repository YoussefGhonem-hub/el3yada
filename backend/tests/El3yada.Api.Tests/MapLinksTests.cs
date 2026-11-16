using El3yada.Api.ClinicAdmin;
using El3yada.Api.Doctors;
using El3yada.Api.Validation;
using FluentValidation.TestHelper;

namespace El3yada.Api.Tests;

/// <summary>A branch's Google Maps link. Same cases as app/test/core/map_links_test.dart.</summary>
public class MapLinksTests
{
    [Theory]
    [InlineData("https://maps.app.goo.gl/AbCd1234XyZ")] // the share sheet's short link
    [InlineData("https://maps.app.goo.gl/AbCd1234XyZ?g_st=iw")]
    [InlineData("http://maps.app.goo.gl/AbCd1234XyZ")]
    [InlineData("HTTPS://MAPS.APP.GOO.GL/AbCd1234XyZ")]
    [InlineData("https://goo.gl/maps/AbCd1234XyZ")] // older short links
    [InlineData("https://maps.google.com/?q=30.0444,31.2357")]
    [InlineData("https://maps.google.com.eg/maps?q=clinic")]
    [InlineData("https://www.google.com/maps/place/Clinic/@30.0444,31.2357,17z")]
    [InlineData("https://www.google.com/maps/search/?api=1&query=30.038000,31.211000")] // what the migration writes
    [InlineData("https://google.com/maps?q=30.0444,31.2357")]
    [InlineData("https://www.google.com.eg/maps/place/عيادة/@30.04,31.23,17z")]
    [InlineData("https://www.google.co.uk/maps/@30.04,31.23,15z")]
    [InlineData("https://www.google.de/maps")]
    [InlineData("  https://maps.app.goo.gl/AbCd1234XyZ  ")] // trimmed first
    public void Accepts_google_maps_links(string link)
    {
        Assert.True(MapLinks.IsGoogleMaps(link));
    }

    [Theory]
    [InlineData("")]
    [InlineData("maps.app.goo.gl/AbCd1234XyZ")] // no scheme
    [InlineData("ftp://maps.app.goo.gl/AbCd1234XyZ")]
    [InlineData("javascript:alert(1)")]
    [InlineData("https://maps.app.goo.gl/")] // no place
    [InlineData("https://goo.gl/AbCd1234")] // a goo.gl link that is not a map
    [InlineData("https://goo.gl/maps/")]
    [InlineData("https://www.google.com/search?q=clinic")] // Google, but not Maps
    [InlineData("https://www.google.com/mapsxyz")]
    [InlineData("https://www.google.com.evil.com/maps/place/x")]
    [InlineData("https://google.com@evil.com/maps")] // user info: the host is evil.com
    [InlineData("https://evil.com/?u=https://maps.app.goo.gl/x")]
    [InlineData("https://maps.google.com.evil.com/x")]
    [InlineData("https://notgoogle.com/maps")]
    [InlineData("https://maps.app.goo.gl:8443/AbCd")] // another port
    [InlineData("https://www.facebook.com/maps/clinic")]
    [InlineData("Clinic https://maps.app.goo.gl/AbCd1234XyZ")] // the app keeps only the link; the API doesn't guess
    [InlineData("30.0444, 31.2357")]
    public void Refuses_anything_else(string link)
    {
        Assert.False(MapLinks.IsGoogleMaps(link));
    }

    [Fact]
    public void The_branch_rules_report_INVALID_MAP_LINK_and_TOO_LONG()
    {
        var address = new BranchAddressInputValidator();
        var valid = new BranchAddressInput("القاهرة", "المعادي", null, "١٢ شارع ٩، الدور التالت", null, "https://maps.app.goo.gl/x");

        address.TestValidate(valid).ShouldNotHaveAnyValidationErrors();
        address.TestValidate(valid with { MapUrl = null }).ShouldNotHaveAnyValidationErrors();
        address.TestValidate(valid with { MapUrl = "  " }).ShouldNotHaveAnyValidationErrors();
        address.TestValidate(valid with { MapUrl = "https://example.com/maps" })
            .ShouldHaveValidationErrorFor(x => x.MapUrl).WithErrorCode(ErrorCodes.InvalidMapLink);
        address.TestValidate(valid with { MapUrl = "https://maps.app.goo.gl/" + new string('x', 500) })
            .ShouldHaveValidationErrorFor(x => x.MapUrl).WithErrorCode(ErrorCodes.TooLong);
        address.TestValidate(valid with { Details = " " })
            .ShouldHaveValidationErrorFor(x => x.Details).WithErrorCode(ErrorCodes.Required);
        address.TestValidate(valid with { Details = new string('ع', 301) })
            .ShouldHaveValidationErrorFor(x => x.Details).WithErrorCode(ErrorCodes.TooLong);
        address.TestValidate(valid with { Details = $"  {new string('ع', 300)}  " }).ShouldNotHaveAnyValidationErrors();

        var signUp = new BranchDataValidator();
        signUp.TestValidate(new BranchData { MapUrl = "https://bit.ly/clinic" })
            .ShouldHaveValidationErrorFor(x => x.MapUrl).WithErrorCode(ErrorCodes.InvalidMapLink);
        signUp.TestValidate(new BranchData())
            .ShouldHaveValidationErrorFor(x => x.AddressDetails).WithErrorCode(ErrorCodes.Required);
    }
}
