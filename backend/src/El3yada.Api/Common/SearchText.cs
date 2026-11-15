using System.Text;

namespace El3yada.Api.Common;

/// <summary>
/// Search normalization (spec A.6), the same steps as the app and the catalog builder: lower case, Arabic-Indic
/// digits → 0–9, no diacritics or tatweel, أ إ آ ٱ → ا, ة → ه, ى → ي, punctuation → spaces (keeping <c>/</c>
/// and <c>.</c> between digits), single spaces. Stored in DoctorPatients.SearchName (D4) and applied to the
/// typed search text, so «أحمد» finds «احمد» and «منة» finds «منه».
/// </summary>
public static class SearchText
{
    public static string Normalize(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return "";
        }

        var lower = text.ToLowerInvariant();
        var builder = new StringBuilder(lower.Length);
        for (var i = 0; i < lower.Length; i++)
        {
            var c = lower[i];
            switch (c)
            {
                case >= '٠' and <= '٩':
                    builder.Append((char)('0' + (c - '٠')));
                    continue;
                case >= '۰' and <= '۹':
                    builder.Append((char)('0' + (c - '۰')));
                    continue;
                case >= 'ً' and <= 'ْ':
                case 'ٰ':
                case 'ـ':
                    continue;
                case 'أ' or 'إ' or 'آ' or 'ٱ':
                    builder.Append('ا');
                    continue;
                case 'ة':
                    builder.Append('ه');
                    continue;
                case 'ى':
                    builder.Append('ي');
                    continue;
            }

            if (char.IsLetterOrDigit(c))
            {
                builder.Append(c);
            }
            else if ((c is '/' or '.') && IsDigitAt(lower, i - 1) && IsDigitAt(lower, i + 1))
            {
                builder.Append(c);
            }
            else if (builder.Length > 0 && builder[^1] != ' ')
            {
                builder.Append(' ');
            }
        }

        return builder.ToString().TrimEnd();
    }

    private static bool IsDigitAt(string text, int index) =>
        index >= 0 && index < text.Length && (char.IsAsciiDigit(text[index]) || text[index] is >= '٠' and <= '٩');
}
