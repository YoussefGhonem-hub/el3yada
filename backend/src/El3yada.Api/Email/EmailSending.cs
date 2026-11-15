using System.Threading.Channels;
using El3yada.Api.Configuration;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace El3yada.Api.Email;

/// <summary>An email to send. <see cref="UserId"/> and <see cref="Kind"/> are for logs, which never hold the address.</summary>
public sealed record EmailMessage(
    string ToAddress, string ToName, string Subject, string TextBody, string HtmlBody, string Kind, Guid? UserId);

/// <summary>Sends one email now. Production: <see cref="SmtpEmailSender"/>; development: <see cref="PickupEmailSender"/>.</summary>
public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken);
}

/// <summary>
/// Emails wait in memory and a background worker sends them, so the request answers at once and takes the
/// same time whether or not an email was sent (forgot password must not reveal which addresses exist).
/// An email still queued when the API stops is lost; the user can ask again.
/// </summary>
public sealed class EmailQueue
{
    private readonly Channel<EmailMessage> _channel = Channel.CreateBounded<EmailMessage>(
        new BoundedChannelOptions(1000) { FullMode = BoundedChannelFullMode.DropWrite });

    public ChannelReader<EmailMessage> Reader => _channel.Reader;

    /// <summary>Queues the message. Returns false when the queue is full (the message is dropped).</summary>
    public bool Enqueue(EmailMessage message) => _channel.Writer.TryWrite(message);
}

public sealed class EmailQueueWorker(EmailQueue queue, IEmailSender sender, ILogger<EmailQueueWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await foreach (var message in queue.Reader.ReadAllAsync(stoppingToken))
            {
                try
                {
                    await sender.SendAsync(message, stoppingToken);
                    logger.LogInformation("Sent {EmailKind} email for user {UserId}", message.Kind, message.UserId);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // The exception message can contain the address, so only its type is logged.
                    logger.LogError("Sending {EmailKind} email for user {UserId} failed: {ErrorType}",
                        message.Kind, message.UserId, ex.GetType().Name);
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Shutting down.
        }
    }
}

/// <summary>Development: writes each email as an .eml file to Email:PickupDirectory (git-ignored), to open in any mail app.</summary>
public sealed class PickupEmailSender(IOptions<EmailOptions> options, IHostEnvironment environment) : IEmailSender
{
    private readonly string _directory = Path.GetFullPath(options.Value.PickupDirectory, environment.ContentRootPath);

    public async Task SendAsync(EmailMessage message, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_directory);
        var mime = EmailMime.Build(message, options.Value);
        var name = $"{DateTime.UtcNow:yyyyMMdd-HHmmss}-{message.Kind}-{Guid.NewGuid():N}.eml";
        var temp = Path.Combine(_directory, name + ".tmp");
        await mime.WriteToAsync(temp, cancellationToken);
        File.Move(temp, Path.Combine(_directory, name));
    }
}

/// <summary>Production: sends through the SMTP server in Email:Smtp (MailKit).</summary>
public sealed class SmtpEmailSender(IOptions<EmailOptions> options) : IEmailSender
{
    public async Task SendAsync(EmailMessage message, CancellationToken cancellationToken)
    {
        var settings = options.Value;
        var mime = EmailMime.Build(message, settings);
        using var client = new SmtpClient { Timeout = 30_000 };
        var security = settings.Smtp.Security switch
        {
            SmtpSecurity.SslOnConnect => SecureSocketOptions.SslOnConnect,
            SmtpSecurity.None => SecureSocketOptions.None,
            _ => SecureSocketOptions.StartTls,
        };
        await client.ConnectAsync(settings.Smtp.Host, settings.Smtp.Port, security, cancellationToken);
        if (!string.IsNullOrEmpty(settings.Smtp.Username))
        {
            await client.AuthenticateAsync(settings.Smtp.Username, settings.Smtp.Password, cancellationToken);
        }

        await client.SendAsync(mime, cancellationToken);
        await client.DisconnectAsync(quit: true, cancellationToken);
    }
}

internal static class EmailMime
{
    public static MimeMessage Build(EmailMessage message, EmailOptions options)
    {
        var mime = new MimeMessage();
        mime.From.Add(new MailboxAddress(options.FromName, options.FromAddress));
        mime.To.Add(new MailboxAddress(message.ToName, message.ToAddress));
        mime.Subject = message.Subject;
        mime.Body = new BodyBuilder { TextBody = message.TextBody, HtmlBody = message.HtmlBody }.ToMessageBody();
        return mime;
    }
}

public static class EmailSetup
{
    public static IServiceCollection AddAppEmail(this IServiceCollection services)
    {
        services.AddSingleton<EmailQueue>();
        services.AddHostedService<EmailQueueWorker>();
        services.AddSingleton<EmailTemplates>();
        // Chosen when first used, from the checked Email options.
        services.AddSingleton<IEmailSender>(provider =>
            provider.GetRequiredService<IOptions<EmailOptions>>().Value.Delivery == EmailDelivery.Smtp
                ? ActivatorUtilities.CreateInstance<SmtpEmailSender>(provider)
                : ActivatorUtilities.CreateInstance<PickupEmailSender>(provider));
        return services;
    }
}
