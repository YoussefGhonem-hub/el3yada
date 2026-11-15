using System.Security.Cryptography;
using System.Text;
using System.Buffers.Text;

namespace El3yada.Api.Auth;

/// <summary>
/// Opaque random tokens (refresh tokens, emailed links). The client gets the token once; the database keeps
/// only its SHA-256 hash (RefreshTokens.TokenHash, UserTokens.TokenHash, 32 bytes), so a database leak
/// does not give working tokens.
/// </summary>
public static class SecretTokens
{
    /// <summary>256 random bits, base64url (43 characters).</summary>
    public static (string Token, byte[] Hash) Create()
    {
        var token = Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));
        return (token, Hash(token));
    }

    public static byte[] Hash(string token) => SHA256.HashData(Encoding.UTF8.GetBytes(token));

    /// <summary>A short, non-reversible fingerprint of the security stamp for the <c>sst</c> claim.</summary>
    public static string StampHash(Guid securityStamp) =>
        Base64Url.EncodeToString(SHA256.HashData(securityStamp.ToByteArray()).AsSpan(0, 12));
}
