import 'package:el3yada/features/patient/domain/dose_text.dart';
import 'package:el3yada/features/patient/domain/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known tokens are recognised', () {
    final parts = DoseParts.of(
      const MedicationItem(
        drugName: 'Concor',
        form: 'tablet',
        dose: '1',
        frequency: '1x1',
        timing: 'afterFood',
        duration: '5d',
      ),
    );
    expect(parts.form, MedicineForm.tablet);
    expect(parts.timing, MedicineTiming.afterFood);
    expect(
      parts.duration,
      isA<DaysDuration>().having((d) => d.count, 'count', 5),
    );
  });

  test('free text stays as typed', () {
    final parts = DoseParts.of(
      const MedicationItem(
        drugName: 'X',
        form: 'لزقة',
        timing: 'unspecified',
        duration: 'حتى الشفاء',
      ),
    );
    expect(parts.form, isNull);
    expect(parts.formText, 'لزقة');
    expect(parts.timing, isNull);
    expect(parts.duration, isA<FreeTextDuration>());
  });

  test('durations', () {
    expect(
      MedicineDuration.parse('2w'),
      isA<WeeksDuration>().having((d) => d.count, 'count', 2),
    );
    expect(MedicineDuration.parse('continuous'), isA<ContinuousDuration>());
    expect(MedicineDuration.parse(' 10 d'), isA<DaysDuration>());
  });

  test('blank fields are dropped', () {
    final parts = DoseParts.of(
      const MedicationItem(drugName: 'X', dose: '  ', instructions: ''),
    );
    expect(parts.dose, isNull);
    expect(parts.instructions, isNull);
  });
}
