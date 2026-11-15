using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using El3yada.Api.Validation;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Tests;

/// <summary>The pattern every endpoint uses: a request record, its validator, and nothing in the action.</summary>
public class ValidationFilterTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task Invalid_input_returns_a_400_ValidationProblem_with_field_errors_and_codes()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/test/sample", new { phone = "0123" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;
        Assert.Equal(400, body.GetProperty("status").GetInt32());
        Assert.Equal("Enter a valid Egyptian mobile number.", body.GetProperty("errors").GetProperty("phone")[0].GetString());
        Assert.Equal(ErrorCodes.InvalidMobile, body.GetProperty("errorCodes").GetProperty("phone")[0].GetString());
        Assert.True(body.TryGetProperty("traceId", out _));
    }

    [Fact]
    public async Task A_field_gets_only_its_first_error()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/test/sample", new { phone = "" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;
        var codes = body.GetProperty("errorCodes").GetProperty("phone");
        Assert.Equal(1, codes.GetArrayLength());
        Assert.Equal("NotEmptyValidator", codes[0].GetString());
    }

    [Fact]
    public async Task Valid_input_reaches_the_action()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/test/sample", new { phone = "٠١٠ ١٢٣٤ ٥٦٧٨" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;
        Assert.Equal("+201012345678", body.GetProperty("phone").GetString());
    }
}

public sealed record SampleRequest(string? Phone);

public sealed class SampleRequestValidator : AbstractValidator<SampleRequest>
{
    public SampleRequestValidator() => RuleFor(x => x.Phone).NotEmpty().EgyptianMobile();
}

[ApiController]
[Route("test/sample")]
[Microsoft.AspNetCore.Authorization.AllowAnonymous]
public sealed class SampleController : ControllerBase
{
    // No validation code here: ValidationFilter runs SampleRequestValidator first.
    [HttpPost]
    public IActionResult Post(SampleRequest request) => Ok(new { phone = EgyptianMobile.Normalize(request.Phone) });
}
