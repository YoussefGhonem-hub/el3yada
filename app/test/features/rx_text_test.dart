import 'dart:ui' show Locale;

import 'package:el3yada/features/prescriptions/pdf/rx_text.dart';
import 'package:el3yada/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Durations are stored as text in the language of the app that wrote them
/// (api-phase-3-prescriptions.md), but each prescription has its own language.
void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('every duration the app writes reads back, from either language', () {
    for (final l10n in [ar, en]) {
      expect(parseRxDuration(rxDurationText(l10n, RxDurationUnit.continuous, 0))?.unit, RxDurationUnit.continuous);
      for (final unit in [RxDurationUnit.days, RxDurationUnit.weeks]) {
        for (final count in [1, 2, 3, 7, 10, 11, 14, 30, 100]) {
          final parts = parseRxDuration(rxDurationText(l10n, unit, count));
          expect(parts, isNotNull, reason: '${l10n.localeName} $unit $count');
          expect(parts!.unit, unit);
          expect(parts.count, count);
        }
      }
    }
  });

  test('an English prescription written from the Arabic app shows English durations', () {
    expect(rxDurationLabel(en, rxDurationText(ar, RxDurationUnit.days, 7)), en.rxDurationDays(7));
    expect(rxDurationLabel(en, 'يومين'), en.rxDurationDays(2));
    expect(rxDurationLabel(en, 'أسبوع'), en.rxDurationWeeks(1));
    expect(rxDurationLabel(en, 'مستمر'), en.rxDurationContinuous);
    expect(rxDurationLabel(ar, en.rxDurationWeeks(3)), ar.rxDurationWeeks(3));
  });

  test('a duration the doctor typed stays as typed', () {
    expect(parseRxDuration('حتى الشفاء'), isNull);
    expect(rxDurationLabel(en, 'حتى الشفاء'), 'حتى الشفاء');
    expect(rxDurationLabel(ar, 'until the next visit'), 'until the next visit');
    expect(rxDurationLabel(en, '7 أيام ثم يوم بعد يوم'), '7 أيام ثم يوم بعد يوم');
  });
}
