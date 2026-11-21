import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../appointments/domain/appointment_models.dart';
import '../../domain/branch_models.dart';
import 'branch_drafts.dart';

// The drafts of D29's schedule tabs (Working hours uses HoursDraft). They save
// through `updateBranchSchedule` (backend/docs/api-phase-6-schedule.md), which
// takes the whole schedule: each tab sends its own part and the others as saved.

extension WeeklyPeriodToBranch on WeeklyPeriod {
  BranchPeriod toBranchPeriod() =>
      BranchPeriod(weekday: weekday, startLocal: start, endLocal: end, endsNextDay: endsNextDay, label: label, capacity: capacity);
}

extension BranchPeriodToWeekly on BranchPeriod {
  WeeklyPeriod toWeekly() =>
      WeeklyPeriod(weekday: weekday, start: startLocal, end: endLocal, endsNextDay: endsNextDay, label: label, capacity: capacity);
}

String _json(Object? value) => jsonEncode(value);

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Special dates (BR-AP13): date-specific hours (none = closed that day), and
/// closures or blocked time for this branch or every branch. Earliest first.
class DatesDraft extends BranchDraft {
  DatesDraft([BranchScheduleData? saved]) {
    if (saved != null) fill(saved);
  }

  List<DateOverride> overrides = const [];
  List<Closure> closures = const [];
  List<DateOverride> _savedOverrides = const [];
  List<Closure> _savedClosures = const [];

  void fill(BranchScheduleData saved) {
    _savedOverrides = saved.overrides;
    _savedClosures = saved.closures;
    overrides = _sorted(saved.overrides);
    closures = _sortedClosures(saved.closures);
    notifyListeners();
  }

  static List<DateOverride> _sorted(List<DateOverride> list) => [...list]..sort((a, b) => a.date.compareTo(b.date));

  static List<Closure> _sortedClosures(List<Closure> list) => [...list]..sort((a, b) => a.from.compareTo(b.from));

  /// Special hours for [date] (no periods = closed), replacing any it had.
  void setDay(DateOverride day) {
    overrides = _sorted([for (final o in overrides) if (!_sameDay(o.date, day.date)) o, day]);
    notifyListeners();
  }

  void removeDay(DateOverride day) {
    overrides = [for (final o in overrides) if (!identical(o, day)) o];
    notifyListeners();
  }

  void addClosure(Closure closure) {
    closures = _sortedClosures([...closures, closure]);
    notifyListeners();
  }

  void removeClosure(Closure closure) {
    closures = [for (final c in closures) if (!identical(c, closure)) c];
    notifyListeners();
  }

  /// The whole day is already closed here (a closed special date, or a closure covering it).
  bool closesWholeDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return overrides.any((o) => _sameDay(o.date, day) && o.periods.isEmpty) ||
        closures.any((c) => !c.from.isAfter(start) && !c.to.isBefore(end));
  }

  @override
  Listenable get edits => this;

  /// Special dates and closures added or removed.
  @override
  int get changes {
    Set<String> keys(List<DateOverride> days, List<Closure> closed) => {
          for (final o in days) 'day ${_json(o.toJson())}',
          for (final c in closed) 'closure ${_json(c.toJson()..remove('id'))}',
        };
    final before = keys(_savedOverrides, _savedClosures);
    final now = keys(overrides, closures);
    return now.difference(before).length + before.difference(now).length;
  }

  @override
  Map<String, BranchProblem> check() => const {};
}

/// Booking settings (spec 6.12.2): every value of the branch's settings.
class BookingSettingsDraft extends BranchDraft {
  BookingSettingsDraft([BookingSettings? saved]) {
    if (saved != null) fill(saved);
  }

  BookingSettings value = const BookingSettings();
  BookingSettings _saved = const BookingSettings();

  BookingSettings get saved => _saved;

  void fill(BookingSettings saved) {
    _saved = saved;
    value = saved;
    notifyListeners();
  }

  void set(BookingSettings next) {
    value = next;
    notifyListeners();
  }

  @override
  Listenable get edits => this;

  /// How many settings differ from the saved ones.
  @override
  int get changes {
    final before = _saved.toJson();
    final now = value.toJson();
    return now.keys.where((k) => _json(now[k]) != _json(before[k])).length;
  }

  @override
  Map<String, BranchProblem> check() => const {};
}
