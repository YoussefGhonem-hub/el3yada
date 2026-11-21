import 'dart:convert';
import 'dart:io';

import 'package:el3yada/features/patient/domain/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests: the fixtures are real responses of the API (`/api/patient/...` on the
/// demo data, see backend/README.md). If the API changes a field, these fail.
Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/patient/$name.json').readAsStringSync());

void main() {
  test('home', () {
    final home = PatientHome.fromJson(fixture('home') as Json);
    expect(home.fullName, isNotEmpty);
    expect(home.latestVisit, isNotNull);
    expect(home.nextFollowUp, isNotNull);
    expect(home.recentFiles, hasLength(2));
    expect(home.latestVisit!.at.isUtc, isTrue);
  });

  test('my doctors', () {
    final doctors = [
      for (final d in fixture('doctors') as List) MyDoctor.fromJson(d as Json),
    ];
    expect(doctors, hasLength(2));
    expect(doctors.every((d) => d.fileNumber > 0), isTrue);
  });

  test('doctor info: branches, hours and price fallback', () {
    final info = DoctorInfo.fromJson(fixture('doctor_info') as Json);
    expect(info.branches, hasLength(2));
    final main = info.branches.first;
    expect(main.isDefault, isTrue);
    expect(main.prices.examinationPiasters, 35000);
    expect(main.prices.consultationPiasters, 15000);
    expect(main.workingHours.first.start, '17:00');
    expect(main.paymentMethods, contains('instapay'));
    expect(info.branches[1].status, BranchStatus.temporarilyClosed);
  });

  test('visits page and visit details', () {
    final page = Paged.fromJson(
      fixture('visits') as Json,
      VisitListItem.fromJson,
    );
    expect(page.totalCount, 2);
    expect(page.hasMore, isFalse);

    final visit = VisitDetail.fromJson(fixture('visit') as Json);
    expect(visit.vitals.bpSys, 150);
    expect(visit.prescriptions, hasLength(3));
    expect(visit.files, hasLength(1));
    expect(visit.followUpDate, isNotNull);
  });

  test('prescriptions', () {
    final page = Paged.fromJson(
      fixture('prescriptions') as Json,
      PrescriptionListItem.fromJson,
    );
    expect(
      page.items.map((p) => p.status),
      containsAll([PrescriptionStatus.sent, PrescriptionStatus.cancelled]),
    );

    final rx = PrescriptionDetail.fromJson(fixture('prescription') as Json);
    expect(rx.kind, PrescriptionKind.medication);
    expect(rx.medications.first.drugName, 'Concor 5 mg');
    expect(rx.hasPdf, isTrue);
    expect(rx.replacesId, isNotNull);
  });

  test('records, counts and record details', () {
    final page = Paged.fromJson(
      fixture('records') as Json,
      RecordListItem.fromJson,
    );
    expect(page.items, hasLength(2));
    final counts = RecordCounts.fromJson(fixture('record_counts') as Json);
    expect(counts.of(RecordCategory.lab), 1);
    expect(counts.of(RecordCategory.other), 1);
    final record = RecordDetail.fromJson(fixture('record') as Json);
    expect(record.title, isNotEmpty);
  });

  test('medical profile and account', () {
    final profile = MedicalProfile.fromJson(fixture('medical_profile') as Json);
    expect(profile.doctors, hasLength(2));
    expect(profile.doctors.expand((d) => d.allergies), contains('البنسلين'));

    final account = PatientAccount.fromJson(fixture('account') as Json);
    expect(account.personal.phone, '+201000000002');
    expect(account.hasPendingDeletion, isFalse);
  });

  test('age is computed from the date of birth', () {
    final person = PersonalInfo(
      patientId: 'p',
      fullName: 'a b',
      phone: '+201',
      gender: 'male',
      dateOfBirth: DateTime(1985, 3, 14),
    );
    expect(person.ageOn(DateTime(2026, 3, 13)), 40);
    expect(person.ageOn(DateTime(2026, 3, 14)), 41);
  });
}
