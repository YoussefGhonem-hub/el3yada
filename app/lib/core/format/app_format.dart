import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../l10n/gen/app_localizations.dart';
import '../validation/validators.dart';

/// Dates, times, money and phone numbers for display (spec section 12):
/// Cairo time, Western digits in both languages, month names in the current
/// language, «30 ج.م» / "EGP 30".
abstract final class AppFormat {
  /// The API's UTC time as Cairo wall-clock time. The fields of the result
  /// are Cairo's; format it, don't convert it again.
  static DateTime cairo(DateTime time) {
    final utc = time.toUtc();
    final local = utc.add(Duration(hours: _cairoSummerTime(utc) ? 3 : 2));
    return DateTime.utc(local.year, local.month, local.day, local.hour, local.minute, local.second);
  }

  /// The UTC instant when [day] (a Cairo calendar day) starts. For date
  /// filters: `from` is the first day's start, `to` the start of the day
  /// after the last one.
  static DateTime cairoDayStartUtc(DateTime day) {
    final guess = DateTime.utc(day.year, day.month, day.day).subtract(const Duration(hours: 2));
    return _cairoSummerTime(guess) ? guess.subtract(const Duration(hours: 1)) : guess;
  }

  /// Egypt's summer time (since 2023): from 00:00 on the last Friday of April
  /// to 24:00 on the last Thursday of October, Cairo time.
  static bool _cairoSummerTime(DateTime utc) {
    final year = utc.year;
    if (year < 2023) return false;
    DateTime lastWeekday(int month, int weekday) {
      var day = DateTime.utc(year, month + 1, 0);
      while (day.weekday != weekday) {
        day = day.subtract(const Duration(days: 1));
      }
      return day;
    }

    // In UTC: starts Thursday 22:00 (00:00 at UTC+2), ends Thursday 21:00 (24:00 at UTC+3).
    final start = lastWeekday(4, DateTime.friday).subtract(const Duration(hours: 2));
    final end = lastWeekday(10, DateTime.thursday).add(const Duration(hours: 21));
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static String _locale(BuildContext context) => Localizations.localeOf(context).languageCode;

  /// «15 نوفمبر 2026» / "Nov 15, 2026".
  static String date(BuildContext context, DateTime time) =>
      DateFormat.yMMMd(_locale(context)).format(cairo(time));

  /// «15 نوفمبر 2026، 10:04 م» / "Nov 15, 2026, 10:04 AM".
  static String dateTime(BuildContext context, DateTime time) {
    final locale = _locale(context);
    final cairoTime = cairo(time);
    final day = DateFormat.yMMMd(locale).format(cairoTime);
    final clock = DateFormat.jm(locale).format(cairoTime);
    return locale == 'ar' ? '$day، $clock' : '$day, $clock';
  }

  /// «منذ ساعتين», "2 hours ago"; a date after a week.
  static String relative(BuildContext context, DateTime time, {DateTime? now}) {
    final l10n = AppLocalizations.of(context);
    final elapsed = (now ?? DateTime.now()).toUtc().difference(time.toUtc());
    if (elapsed.inMinutes < 1) return l10n.adminJustNow;
    if (elapsed.inHours < 1) return l10n.adminMinutesAgo(elapsed.inMinutes);
    if (elapsed.inDays < 1) return l10n.adminHoursAgo(elapsed.inHours);
    if (elapsed.inDays < 7) return l10n.adminDaysAgo(elapsed.inDays);
    return date(context, time);
  }

  /// 30000 piasters → «300 ج.م» / "EGP 300"; 15050 → "EGP 150.50".
  static String egp(BuildContext context, int piasters) =>
      AppLocalizations.of(context).adminMoneyEgp(egpNumber(piasters));

  /// The amount in EGP without the currency: `300`, `150.50`, `1,250`.
  static String egpNumber(int piasters) {
    final pounds = NumberFormat('#,##0', 'en').format(piasters ~/ 100);
    final rest = piasters.abs() % 100;
    return rest == 0 ? pounds : '$pounds.${rest.toString().padLeft(2, '0')}';
  }

  /// EGP typed by the admin (`300`, `150.5`, `1,250.75`, Arabic digits too)
  /// → piasters, or null when it isn't an amount with at most 2 decimals.
  static int? parseEgp(String text) {
    final value = Validators.normalizeDigits(text.trim()).replaceAll(',', '').replaceAll('٫', '.');
    final match = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(value);
    if (match == null) return null;
    final pounds = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return pounds * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  /// An E.164 Egyptian number as Egyptians write it: `+201012345678` →
  /// `010 1234 5678`, `+20223581234` → `02 2358 1234`. Other numbers as
  /// they are. Show it left to right ([LtrText]).
  static String phone(String number) {
    if (!number.startsWith('+20')) return number;
    final local = '0${number.substring(3)}';
    if (local.length == 11 && local.startsWith('01')) {
      return '${local.substring(0, 3)} ${local.substring(3, 7)} ${local.substring(7)}';
    }
    if (local.length == 10 && (local.startsWith('02') || local.startsWith('03'))) {
      return '${local.substring(0, 2)} ${local.substring(2, 6)} ${local.substring(6)}';
    }
    if (local.length == 10) return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    return local;
  }
}

/// Text that always reads left to right, even in Arabic: phone numbers,
/// amounts, versions, emails, IDs (spec section 12).
class LtrText extends StatelessWidget {
  const LtrText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: style, maxLines: maxLines, overflow: overflow, textDirection: TextDirection.ltr);
}
