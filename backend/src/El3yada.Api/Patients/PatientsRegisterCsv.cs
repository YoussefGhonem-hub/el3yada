using System.Globalization;
using System.Text;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Data;

namespace El3yada.Api.Patients;

/// <summary>
/// D4 [S] "Export CSV" (<c>GET /api/patients/register/export</c>): every row of the register for the same
/// filters and sort as the screen, in Arabic or English. Money and clinical columns follow the same
/// permissions as the rows. UTF-8 with a BOM and CRLF rows, so Excel opens Arabic text correctly.
/// </summary>
public static class PatientsRegisterCsv
{
    /// <summary>Rows read per query.</summary>
    public const int ChunkSize = 500;

    /// <summary>An export with more rows is refused with <c>EXPORT_TOO_LARGE</c>; narrow the filters.</summary>
    public const int MaxRows = 20_000;

    private sealed record Window(int Page, int PageSize) : IPagedQuery;

    /// <summary>The file, or null when the filters match more than <see cref="MaxRows"/> patients.</summary>
    public static async Task<(byte[] Content, int Rows)?> BuildAsync(
        AppDbContext db, ClinicCaller caller, PatientsRegisterQuery query, DateOnly today, bool arabic, CancellationToken cancellationToken)
    {
        var revenue = caller.Has(ClinicPermissions.RevenueView);
        var clinical = caller.Has(ClinicPermissions.ClinicalView);
        string T(string ar, string en) => arabic ? ar : en;

        var csv = new StringBuilder();
        var header = new List<string>
        {
            T("رقم الملف", "File number"), T("الاسم", "Name"), T("الموبايل", "Mobile"), T("النوع", "Gender"), T("السن", "Age"),
            T("أول زيارة", "First visit"), T("آخر زيارة", "Last visit"), T("نوع آخر زيارة", "Last visit type"),
            T("فرع آخر زيارة", "Last visit branch"), T("الزيارات", "Visits"), T("كشف", "Examinations"), T("استشارة", "Consultations"),
            T("الحجز القادم", "Next booking"), T("مرات الغياب", "No-shows"), T("الملفات", "Files"),
        };
        if (revenue)
        {
            header.Add(T("إجمالي المدفوع (ج.م)", "Total paid (EGP)"));
        }

        if (clinical)
        {
            header.Add(T("حساسية", "Allergies"));
            header.Add(T("أمراض مزمنة", "Chronic diseases"));
        }

        header.Add(T("تاريخ الإضافة", "Added on"));
        WriteRow(csv, header);

        var rows = 0;
        for (var page = 1; ; page++)
        {
            var result = await PatientsRegister.PageAsync(db, caller, query, new Window(page, ChunkSize), today, cancellationToken);
            if (result.TotalCount > MaxRows)
            {
                return null;
            }

            foreach (var row in result.Items)
            {
                var last = row.Visits.LastVisit;
                var cells = new List<string>
                {
                    Number(row.FileNumber),
                    row.FullName,
                    LocalPhone(row.Phone),
                    row.Gender == "female" ? T("أنثى", "Female") : T("ذكر", "Male"),
                    Number(row.AgeYears),
                    row.Visits.FirstVisitAt is { } first ? Day(CairoTime.DayOf(first)) : "",
                    last is null ? "" : Day(last.Day),
                    last is null ? "" : VisitType(last.Type, arabic),
                    last is null ? "" : arabic || last.BranchNameEn is null ? last.BranchNameAr : last.BranchNameEn,
                    Number(row.Visits.Total),
                    Number(row.Visits.Examinations),
                    Number(row.Visits.Consultations),
                    row.NextBooking is { } next ? Day(next.Date) : "",
                    Number(row.NoShowCount),
                    Number(row.FilesCount),
                };
                if (revenue)
                {
                    cells.Add(((row.TotalPaidPiasters ?? 0) / 100m).ToString("0.00", CultureInfo.InvariantCulture));
                }

                if (clinical)
                {
                    cells.Add(row.HasAllergies == true ? T("نعم", "Yes") : T("لا", "No"));
                    cells.Add(string.Join(arabic ? "، " : "; ", row.ChronicDiseases ?? []));
                }

                cells.Add(Day(CairoTime.DayOf(row.LinkedAt)));
                WriteRow(csv, cells);
                rows++;
            }

            if (page * ChunkSize >= result.TotalCount)
            {
                break;
            }
        }

        var bytes = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(csv.ToString())).ToArray();
        return (bytes, rows);
    }

    /// <summary>The download's name: <c>patients-2026-11-21.csv</c>.</summary>
    public static string FileName(DateOnly today) => $"patients-{Day(today)}.csv";

    private static string Number(int value) => value.ToString(CultureInfo.InvariantCulture);

    private static string Day(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private static string VisitType(string type, bool arabic) => type == "consultation"
        ? arabic ? "استشارة" : "Consultation"
        : arabic ? "كشف" : "Examination";

    /// <summary>
    /// +201012345678 → <c>010 1234 5678</c>. The spaces keep spreadsheets from reading it as a number and
    /// dropping the leading zero.
    /// </summary>
    public static string LocalPhone(string e164)
    {
        if (!e164.StartsWith("+20", StringComparison.Ordinal) || e164.Length != 13)
        {
            return e164;
        }

        var local = "0" + e164[3..];
        return $"{local[..3]} {local[3..7]} {local[7..]}";
    }

    private static void WriteRow(StringBuilder csv, IEnumerable<string> cells)
    {
        csv.Append(string.Join(',', cells.Select(Escape)));
        csv.Append("\r\n");
    }

    /// <summary>
    /// RFC 4180 quoting, and a leading apostrophe on text a spreadsheet would run as a formula
    /// (<c>= + - @</c>, tab, CR), so a patient's name can never become one (CSV injection).
    /// </summary>
    public static string Escape(string value)
    {
        if (value.Length > 0 && value[0] is '=' or '+' or '-' or '@' or '\t' or '\r')
        {
            value = "'" + value;
        }

        return value.IndexOfAny([',', '"', '\r', '\n']) >= 0 ? "\"" + value.Replace("\"", "\"\"", StringComparison.Ordinal) + "\"" : value;
    }
}
