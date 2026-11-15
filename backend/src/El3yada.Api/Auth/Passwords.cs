using System.Security.Cryptography;
using El3yada.Api.Validation;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Identity;

namespace El3yada.Api.Auth;

/// <summary>
/// Password rules (spec section 11) and hashing. Hashes come from ASP.NET Core Identity's
/// <see cref="PasswordHasher{TUser}"/> (PBKDF2 with HMAC-SHA512, salted, format v3), stored in Users.PasswordHash.
/// </summary>
public sealed class Passwords(IPasswordHasher<User> hasher)
{
    public const int MinLength = 8;

    /// <summary>Longer input is refused, so a huge password can't tie up the hasher.</summary>
    public const int MaxLength = 128;

    /// <summary>Patients and assistants (BR-P4, BR-AS2).</summary>
    public const int TemporaryLength = 8;

    /// <summary>Admins (createAdmin, seed-admin).</summary>
    public const int AdminTemporaryLength = 12;

    // No 0/O, 1/l/I: the temporary password is read aloud or copied by hand.
    private const string Letters = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
    private const string Digits = "23456789";

    // Verifying against this keeps a login with an unknown identifier about as slow as a real one.
    private static readonly Lazy<string> DummyHash = new(() => new PasswordHasher<User>().HashPassword(new User(), "dummy-password-1"));

    /// <summary>≥ 8 characters, at least one letter and one digit, at most 128 characters.</summary>
    public static bool MeetsPolicy(string? password)
    {
        if (password is null)
        {
            return false;
        }

        var value = Normalize(password);
        return value.Length is >= MinLength and <= MaxLength
            && value.Any(char.IsLetter)
            && value.Any(char.IsAsciiDigit);
    }

    /// <summary>
    /// Arabic-Indic and Persian digits become 0-9 before hashing and checking, so a password typed on an
    /// Arabic keyboard matches the same password typed with Western digits. Nothing else is changed.
    /// </summary>
    public static string Normalize(string password) => EgyptianMobile.NormalizeDigits(password);

    public string Hash(User user, string password) => hasher.HashPassword(user, Normalize(password));

    /// <summary>
    /// Checks <paramref name="password"/> against the user's hash. When the hash uses older settings,
    /// it is replaced in <c>user.PasswordHash</c> (the caller saves).
    /// </summary>
    public bool Verify(User user, string password)
    {
        if (string.IsNullOrEmpty(user.PasswordHash))
        {
            VerifyDummy(password);
            return false;
        }

        var result = hasher.VerifyHashedPassword(user, user.PasswordHash, Normalize(password));
        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = Hash(user, password);
        }

        return result is PasswordVerificationResult.Success or PasswordVerificationResult.SuccessRehashNeeded;
    }

    /// <summary>Spends the same time as a real check, for identifiers with no account.</summary>
    public void VerifyDummy(string password) =>
        hasher.VerifyHashedPassword(new User(), DummyHash.Value, Normalize(password));

    /// <summary>A random password with letters and digits (at least one of each), shown to the user once.</summary>
    public static string GenerateTemporary(int length = TemporaryLength)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(length, MinLength);
        const string all = Letters + Digits;
        while (true)
        {
            var chars = new char[length];
            for (var i = 0; i < length; i++)
            {
                chars[i] = all[RandomNumberGenerator.GetInt32(all.Length)];
            }

            var value = new string(chars);
            if (value.Any(char.IsLetter) && value.Any(char.IsAsciiDigit))
            {
                return value;
            }
        }
    }
}
