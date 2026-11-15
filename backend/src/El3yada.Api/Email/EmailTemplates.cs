using System.Net;
using El3yada.Api.Configuration;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Email;

/// <summary>
/// The Phase 1 emails, in Arabic and English (the recipient's language first). The link is
/// Email:ResetPasswordUrl or Email:VerifyEmailUrl with <c>?token=…</c>; the same token is shown as a code to
/// paste into the app when the link doesn't open it (for example on Windows).
/// </summary>
public sealed class EmailTemplates(IOptions<EmailOptions> options)
{
    public EmailMessage PasswordReset(string toAddress, string toName, string locale, string token, int validMinutes, Guid userId)
    {
        var link = Link(options.Value.ResetPasswordUrl, token);
        var ar = new Section(
            "rtl",
            $"مرحباً {toName}،",
            "طلبت إعادة تعيين كلمة المرور لحسابك في العيادة. اضغط على الرابط لاختيار كلمة مرور جديدة:",
            "إعادة تعيين كلمة المرور",
            $"الرابط صالح لمدة {validMinutes} دقيقة ويُستخدم مرة واحدة. إذا لم يفتح الرابط التطبيق، انسخ هذا الرمز في التطبيق:",
            "إذا لم تطلب ذلك، تجاهل هذه الرسالة؛ لن تتغير كلمة المرور.");
        var en = new Section(
            "ltr",
            $"Hello {toName},",
            "You asked to reset the password of your el3yada account. Open the link to choose a new password:",
            "Reset password",
            $"The link works once, for {validMinutes} minutes. If it doesn't open the app, paste this code into the app:",
            "If you didn't ask for this, ignore this email; your password stays the same.");
        return Build(toAddress, toName, locale, "إعادة تعيين كلمة المرور | Reset your el3yada password",
            link, token, ar, en, "passwordReset", userId);
    }

    public EmailMessage VerifyEmail(string toAddress, string toName, string locale, string token, int validHours, Guid userId)
    {
        var link = Link(options.Value.VerifyEmailUrl, token);
        var ar = new Section(
            "rtl",
            $"مرحباً {toName}،",
            "شكراً لتسجيلك في العيادة. اضغط على الرابط لتأكيد بريدك الإلكتروني:",
            "تأكيد البريد الإلكتروني",
            $"الرابط صالح لمدة {validHours} ساعة. إذا لم يفتح الرابط التطبيق، انسخ هذا الرمز في التطبيق:",
            "إذا لم تسجل في العيادة، تجاهل هذه الرسالة.");
        var en = new Section(
            "ltr",
            $"Hello {toName},",
            "Thanks for signing up to el3yada. Open the link to verify your email address:",
            "Verify email",
            $"The link works for {validHours} hours. If it doesn't open the app, paste this code into the app:",
            "If you didn't sign up to el3yada, ignore this email.");
        return Build(toAddress, toName, locale, "تأكيد البريد الإلكتروني | Verify your el3yada email",
            link, token, ar, en, "emailVerify", userId);
    }

    private sealed record Section(string Dir, string Greeting, string Intro, string Button, string CodeNote, string Ignore);

    private static string Link(string baseUrl, string token) => $"{baseUrl}?token={Uri.EscapeDataString(token)}";

    private static EmailMessage Build(
        string toAddress, string toName, string locale, string subject, string link, string token,
        Section ar, Section en, string kind, Guid userId)
    {
        var sections = locale == "en" ? new[] { en, ar } : [ar, en];
        var text = string.Join("\n\n----\n\n", sections.Select(s =>
            $"{s.Greeting}\n\n{s.Intro}\n{link}\n\n{s.CodeNote}\n{token}\n\n{s.Ignore}"));
        var html = "<!doctype html><html><body style=\"font-family:Arial,Tahoma,sans-serif;font-size:15px;color:#1b1b1b\">"
            + string.Join("<hr style=\"border:none;border-top:1px solid #ddd;margin:24px 0\">", sections.Select(s =>
                $"<div dir=\"{s.Dir}\"><p>{E(s.Greeting)}</p><p>{E(s.Intro)}</p>"
                + $"<p><a href=\"{E(link)}\" style=\"display:inline-block;background:#0F4C45;color:#fff;padding:10px 18px;border-radius:8px;text-decoration:none\">{E(s.Button)}</a></p>"
                + $"<p style=\"color:#555\">{E(s.CodeNote)}<br><code dir=\"ltr\" style=\"font-size:13px\">{E(token)}</code></p>"
                + $"<p style=\"color:#555\">{E(s.Ignore)}</p></div>"))
            + "</body></html>";
        return new EmailMessage(toAddress, toName, subject, text, html, kind, userId);
    }

    private static string E(string value) => WebUtility.HtmlEncode(value);
}
