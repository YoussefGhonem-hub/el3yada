import '../../../core/validation/validators.dart';
import 'branch_models.dart';

/// A rule a period breaks: the period's index in the list, the field
/// (`startLocal`, `endLocal`, `label`, `capacity`, or '' for the whole
/// period) and the API's error code.
class PeriodProblem {
  const PeriodProblem(this.index, this.field, this.code);

  final int index;
  final String field;
  final String code;

  @override
  bool operator ==(Object other) => other is PeriodProblem && other.index == index && other.field == field && other.code == code;

  @override
  int get hashCode => Object.hash(index, field, code);

  @override
  String toString() => 'PeriodProblem($index, $field, $code)';
}

/// Weekly working hours (BR-BR2, spec section 11 "Working hours"), the same
/// rules as the API's `WeeklyHours.Check` (backend/src/El3yada.Api/
/// ClinicAdmin/WeeklyHours.cs), so the D29 grid shows the problem before
/// saving. Change both together.
abstract final class WeeklyHours {
  static const minLengthMinutes = 15;
  static const maxLengthMinutes = 16 * 60;
  static const maxPeriodsPerDay = 10;
  static const minCapacity = 1;
  static const maxCapacity = 200;
  static const maxLabelChars = 30;

  static const _minutesPerDay = 24 * 60;
  static const _minutesPerWeek = 7 * _minutesPerDay;

  /// The Egyptian week, Saturday first, as ISO weekdays.
  static const weekOrder = [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday];

  static final _time = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// "HH:mm" (Arabic-Indic digits allowed) as minutes since midnight, or null.
  static int? parse(String? value) {
    if (value == null) return null;
    final match = _time.firstMatch(Validators.normalizeDigits(value.trim()));
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  /// Minutes since midnight as "HH:mm".
  static String format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// How long a period lasts. A next-day period runs past midnight.
  static int lengthMinutes(int start, int end, {required bool endsNextDay}) =>
      endsNextDay ? _minutesPerDay - start + end : end - start;

  /// Every problem in the week, as the API reports them: the single fields
  /// first (times, label, capacity); then, once every period's times can be
  /// read, the order, the length and overlaps (on the later period), and
  /// more than [maxPeriodsPerDay] in a day (index -1).
  static List<PeriodProblem> check(List<BranchPeriod> periods) {
    final problems = <PeriodProblem>[];
    for (final (i, period) in periods.indexed) {
      if (period.startLocal.trim().isEmpty) {
        problems.add(PeriodProblem(i, 'startLocal', 'REQUIRED'));
      } else if (parse(period.startLocal) == null) {
        problems.add(PeriodProblem(i, 'startLocal', 'INVALID_VALUE'));
      }
      if (period.endLocal.trim().isEmpty) {
        problems.add(PeriodProblem(i, 'endLocal', 'REQUIRED'));
      } else if (parse(period.endLocal) == null) {
        problems.add(PeriodProblem(i, 'endLocal', 'INVALID_VALUE'));
      }
      if ((period.label ?? '').trim().length > maxLabelChars) problems.add(PeriodProblem(i, 'label', 'TOO_LONG'));
      final capacity = period.capacity;
      if (capacity != null && (capacity < minCapacity || capacity > maxCapacity)) {
        problems.add(PeriodProblem(i, 'capacity', 'OUT_OF_RANGE'));
      }
    }
    if (problems.any((p) => p.field == 'startLocal' || p.field == 'endLocal')) return problems;

    final valid = <(int, int, int)>[];
    for (final (i, period) in periods.indexed) {
      final start = parse(period.startLocal)!;
      final end = parse(period.endLocal)!;
      final length = lengthMinutes(start, end, endsNextDay: period.endsNextDay);
      if (!period.endsNextDay && length <= 0) {
        problems.add(PeriodProblem(i, 'endLocal', 'PERIOD_END_BEFORE_START'));
        continue;
      }
      if (length < minLengthMinutes || length > maxLengthMinutes) {
        problems.add(PeriodProblem(i, 'endLocal', 'PERIOD_LENGTH_OUT_OF_RANGE'));
        continue;
      }
      final from = (period.weekday - 1) * _minutesPerDay + start;
      final to = from + length;
      if (valid.any((other) => _overlap(other.$2, other.$3, from, to))) {
        problems.add(PeriodProblem(i, '', 'PERIODS_OVERLAP'));
        continue;
      }
      valid.add((i, from, to));
    }

    final perDay = <int, int>{};
    for (final period in periods) {
      perDay.update(period.weekday, (n) => n + 1, ifAbsent: () => 1);
    }
    if (perDay.values.any((n) => n > maxPeriodsPerDay)) problems.add(const PeriodProblem(-1, '', 'INVALID_VALUE'));
    return problems;
  }

  /// The week with every other day replaced by copies of [from]'s periods
  /// ("Copy Saturday to all days", done in the app).
  static List<BranchPeriod> copyDayToAll(List<BranchPeriod> periods, {int from = DateTime.saturday}) {
    final source = periods.where((p) => p.weekday == from).toList();
    return [
      for (final day in weekOrder)
        if (day == from) ...source else ...[for (final p in source) p.copyWith(weekday: day)],
    ];
  }

  /// The periods of [weekday], earliest first.
  static List<BranchPeriod> ofDay(List<BranchPeriod> periods, int weekday) =>
      periods.where((p) => p.weekday == weekday).toList()
        ..sort((a, b) => (parse(a.startLocal) ?? 0).compareTo(parse(b.startLocal) ?? 0));

  /// Half-open ranges on a circular week: Sunday's late period can run into
  /// Monday morning (ISO Monday is day 1).
  static bool _overlap(int aStart, int aEnd, int bStart, int bEnd) =>
      _linear(aStart, aEnd, bStart, bEnd) ||
      _linear(aStart, aEnd, bStart + _minutesPerWeek, bEnd + _minutesPerWeek) ||
      _linear(aStart + _minutesPerWeek, aEnd + _minutesPerWeek, bStart, bEnd);

  static bool _linear(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && bStart < aEnd;
}
