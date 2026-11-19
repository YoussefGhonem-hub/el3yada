using FirebaseAdmin;
using FirebaseAdmin.Auth;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace El3yada.Api.Infrastructure.Firebase;

/// <summary>
/// Section <c>Firebase</c>. Leave <c>CredentialsPath</c> empty to run without Firebase: pushes are
/// skipped (logged), the Firestore mirror is off, and apps use SignalR and the 15-second API refresh.
/// The service-account file is a secret: keep it outside the repo.
/// </summary>
public sealed class FirebaseOptions
{
    public const string Section = "Firebase";

    public string? ProjectId { get; set; }

    /// <summary>Path to the service-account JSON (FCM, custom tokens, Firestore).</summary>
    public string? CredentialsPath { get; set; }

    public bool Enabled => !string.IsNullOrWhiteSpace(CredentialsPath) && !string.IsNullOrWhiteSpace(ProjectId);
}

/// <summary>One push message, already in the recipient's language. Never holds diagnoses (spec 10.1).</summary>
public sealed record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

public interface IPushSender
{
    /// <summary>Sends to the device tokens. Returns the tokens FCM rejected as invalid, to delete them.</summary>
    Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct);
}

/// <summary>Used while Firebase isn't configured.</summary>
public sealed class NoopPushSender(ILogger<NoopPushSender> logger) : IPushSender
{
    public Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct)
    {
        logger.LogDebug("Push skipped (Firebase not configured): {Count} devices", tokens.Count);
        return Task.FromResult<IReadOnlyList<string>>([]);
    }
}

/// <summary>FCM HTTP v1 through the Firebase Admin SDK.</summary>
public sealed class FcmPushSender(FirebaseApp app, ILogger<FcmPushSender> logger) : IPushSender
{
    public async Task<IReadOnlyList<string>> SendAsync(IReadOnlyList<string> tokens, PushMessage message, CancellationToken ct)
    {
        if (tokens.Count == 0) return [];
        // The Flutter firebase_messaging plugin still issues registration tokens, which FCM accepts.
        // Move to installation ids (Fid) once the app sends them.
#pragma warning disable CS0618
        var messages = tokens.Select(token => new Message
        {
            Token = token,
#pragma warning restore CS0618
            Notification = new Notification { Title = message.Title, Body = message.Body },
            Data = message.Data,
            Android = new AndroidConfig { Priority = Priority.High },
        }).ToList();
        var response = await FirebaseMessaging.GetMessaging(app).SendEachAsync(messages, ct);

        var invalid = new List<string>();
        for (var i = 0; i < response.Responses.Count; i++)
        {
            var error = response.Responses[i].Exception?.MessagingErrorCode;
            if (error is MessagingErrorCode.Unregistered or MessagingErrorCode.InvalidArgument) invalid.Add(tokens[i]);
            else if (response.Responses[i].Exception is { } ex) logger.LogWarning(ex, "FCM send failed");
        }
        return invalid;
    }
}

/// <summary>Firebase custom tokens for the app's Firestore sign-in (<c>getRealtimeToken</c>, spec 9.6).</summary>
public interface IRealtimeTokenIssuer
{
    bool Enabled { get; }
    Task<string> CreateAsync(Guid userId, IReadOnlyDictionary<string, object> claims, CancellationToken ct);
}

public sealed class DisabledRealtimeTokenIssuer : IRealtimeTokenIssuer
{
    public bool Enabled => false;
    public Task<string> CreateAsync(Guid userId, IReadOnlyDictionary<string, object> claims, CancellationToken ct) =>
        throw new InvalidOperationException("Firebase is not configured.");
}

public sealed class FirebaseRealtimeTokenIssuer(FirebaseApp app) : IRealtimeTokenIssuer
{
    public bool Enabled => true;

    public Task<string> CreateAsync(Guid userId, IReadOnlyDictionary<string, object> claims, CancellationToken ct) =>
        FirebaseAuth.GetAuth(app).CreateCustomTokenAsync(userId.ToString(), claims.ToDictionary(), ct);
}

public static class FirebaseSetup
{
    public static IServiceCollection AddEl3yadaFirebase(this IServiceCollection services, IConfiguration configuration)
    {
        var options = configuration.GetSection(FirebaseOptions.Section).Get<FirebaseOptions>() ?? new FirebaseOptions();
        services.AddSingleton(options);

        if (!options.Enabled)
        {
            services.AddSingleton<IPushSender, NoopPushSender>();
            services.AddSingleton<IRealtimeTokenIssuer, DisabledRealtimeTokenIssuer>();
            services.AddSingleton<ILiveBoardMirror, NoopLiveBoardMirror>();
            return services;
        }

        services.AddSingleton(_ => FirebaseApp.Create(new AppOptions
        {
            Credential = CredentialFactory.FromFile<ServiceAccountCredential>(options.CredentialsPath!).ToGoogleCredential(),
            ProjectId = options.ProjectId,
        }, "el3yada"));
        services.AddSingleton<IPushSender, FcmPushSender>();
        services.AddSingleton<IRealtimeTokenIssuer, FirebaseRealtimeTokenIssuer>();
        services.AddSingleton<ILiveBoardMirror, FirestoreLiveBoardMirror>();
        return services;
    }
}
