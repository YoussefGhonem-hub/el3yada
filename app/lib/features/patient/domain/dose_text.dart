import 'patient_models.dart';

/// Known values of the free-text medication fields (spec 6.4). The editor (D13) saves
/// these tokens; anything else is shown exactly as the doctor typed it.
enum MedicineForm { tablet, capsule, syrup, injection, cream, drops, inhaler, suppository, sachet, other }

enum MedicineTiming { beforeFood, afterFood, withFood }

/// A duration token: `5d`, `2w`, `continuous`, or free text.
sealed class MedicineDuration {
  const MedicineDuration();

  static MedicineDuration parse(String raw) {
    final value = raw.trim();
    if (value == 'continuous') return const ContinuousDuration();
    final match = RegExp(r'^(\d+)\s*([dw])$').firstMatch(value);
    if (match == null) return FreeTextDuration(value);
    final count = int.parse(match.group(1)!);
    return match.group(2) == 'd' ? DaysDuration(count) : WeeksDuration(count);
  }
}

final class DaysDuration extends MedicineDuration {
  const DaysDuration(this.count);
  final int count;
}

final class WeeksDuration extends MedicineDuration {
  const WeeksDuration(this.count);
  final int count;
}

final class ContinuousDuration extends MedicineDuration {
  const ContinuousDuration();
}

final class FreeTextDuration extends MedicineDuration {
  const FreeTextDuration(this.text);
  final String text;
}

/// The parts of one medicine line, already split into known tokens (P7, "plain words").
/// The presentation layer turns each part into localized text.
class DoseParts {
  const DoseParts({this.form, this.formText, this.dose, this.frequency, this.timing, this.duration, this.instructions});

  /// A known form, or null with [formText] holding what the doctor typed.
  final MedicineForm? form;
  final String? formText;
  final String? dose;
  final String? frequency;

  /// Null when not specified.
  final MedicineTiming? timing;
  final MedicineDuration? duration;
  final String? instructions;

  factory DoseParts.of(MedicationItem item) {
    String? clean(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();

    final formRaw = clean(item.form);
    final form = MedicineForm.values.where((f) => f.name == formRaw).firstOrNull;
    final timingRaw = clean(item.timing);
    final durationRaw = clean(item.duration);

    return DoseParts(
      form: form,
      formText: form == null ? formRaw : null,
      dose: clean(item.dose),
      frequency: clean(item.frequency),
      timing: MedicineTiming.values.where((t) => t.name == timingRaw).firstOrNull,
      duration: durationRaw == null ? null : MedicineDuration.parse(durationRaw),
      instructions: clean(item.instructions),
    );
  }
}
