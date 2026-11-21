import 'dart:convert';
import 'dart:typed_data';

import 'package:el3yada/core/notifications/local_notifier.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:el3yada/features/clinic_admin/application/branch_photo_picker.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:el3yada/features/patient/data/fake_patient_repository.dart';
import 'package:el3yada/features/patient/data/patient_repository.dart';
import 'package:el3yada/features/patient/domain/patient_models.dart';
import 'package:el3yada/features/patient/presentation/widgets/branch_photo_strip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// A 1 × 1 PNG: real image bytes for the fakes.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

/// Hands back the photos a test chooses, without the system dialog.
class _Picker implements BranchPhotoPicker {
  List<PickedPhoto> next = const [];
  int? askedFor;

  @override
  Future<List<PickedPhoto>> pick({required int max}) async {
    askedFor = max;
    return next.take(max).toList();
  }
}

/// The offline patient app, with photos on doctor A's Maadi branch.
class _PatientWithPhotos extends FakePatientRepository {
  _PatientWithPhotos() : super(delay: Duration.zero);

  final asked = <String>[];

  @override
  Future<DoctorInfo> doctor(String doctorId) async {
    final info = await super.doctor(doctorId);
    final b = info.branches.first;
    return DoctorInfo(
      doctor: info.doctor, specialty: info.specialty, degreesAr: info.degreesAr, degreesEn: info.degreesEn,
      doctorStatus: info.doctorStatus, fileNumber: info.fileNumber,
      branches: [
        BranchInfo(
          id: b.id, nameAr: b.nameAr, nameEn: b.nameEn, description: b.description, isDefault: b.isDefault, status: b.status,
          closedMessage: b.closedMessage, reopenDate: b.reopenDate, address: b.address, email: b.email, phones: b.phones,
          workingHours: b.workingHours, prices: b.prices, paymentMethods: b.paymentMethods, amenities: b.amenities,
          photoIds: const ['photo-1', 'photo-2'],
        ),
        ...info.branches.skip(1),
      ],
    );
  }

  @override
  Future<Uint8List> branchPhoto(String doctorId, String branchId, String photoId, {bool thumbnail = false}) async {
    asked.add('$doctorId/$branchId/$photoId${thumbnail ? '?thumb' : ''}');
    return _png;
  }
}

void main() {
  const maadi = FakeClinicAdminRepository.maadiBranchId;

  Future<_Picker> doctor(WidgetTester tester, {void Function(FakeClinicAdminRepository fake)? configure, String who = 'doctor@el3yada.dev'}) async {
    final picker = _Picker();
    await pumpApp(tester, extra: [
      fakeClinicAdminOverride(configure: configure),
      branchPhotoPickerProvider.overrideWithValue(picker),
    ]);
    await signIn(tester, who);
    return picker;
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  group('D29 photos', () {
    testWidgets('the doctor adds photos, puts them in order and removes one; the first is the cover', (tester) async {
      final picker = await doctor(tester);
      await open(tester, '/doctor/branches/$maadi?tab=info');

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('0 of 5'), findsOneWidget);
      picker.next = [(name: 'waiting-room.png', bytes: _png), (name: 'entrance.png', bytes: _png)];
      await tester.ensureVisible(find.text('Add photos'));
      await tester.tap(find.text('Add photos'));
      await settle(tester);

      expect(picker.askedFor, 5);
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('2 photos added'), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      final fake = clinicAdminFake(tester);
      final before = fake.photoIdsOf(maadi);
      expect(before, hasLength(2));

      // The second photo becomes the cover.
      await tester.ensureVisible(find.byTooltip('Move earlier').last);
      await tester.tap(find.byTooltip('Move earlier').last);
      await settle(tester);
      expect(fake.photoIdsOf(maadi), before.reversed);

      await tester.tap(find.byTooltip('Remove').first);
      await settle(tester);
      expect(find.text('Remove this photo?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(tester);
      expect(fake.photoIdsOf(maadi), [before.first]);
      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('at five photos there is no Add, and a refused file says why', (tester) async {
      final picker = await doctor(tester);
      final fake = clinicAdminFake(tester);
      for (var i = 0; i < 4; i++) {
        fake.seedPhoto(maadi, _png);
      }
      await open(tester, '/doctor/branches/$maadi?tab=info');

      // Not an image: the fake refuses it like the API.
      picker.next = [(name: 'notes.txt', bytes: Uint8List.fromList(utf8.encode('not a photo')))];
      await tester.ensureVisible(find.text('Add photos'));
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(find.text('Use a JPEG, PNG or WebP photo.'), findsOneWidget);

      picker.next = [(name: 'last.png', bytes: _png)];
      await tester.tap(find.text('Add photos'));
      await settle(tester);
      expect(picker.askedFor, 1);
      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.text('Add photos'), findsNothing);
    });

    testWidgets('AS17 shows the photos read-only', (tester) async {
      await doctor(tester, who: '+201000000005', configure: (fake) => fake.seedPhoto(maadi, _png));
      await open(tester, '/assistant/schedule?tab=info');

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      expect(find.text('Add photos'), findsNothing);
      expect(find.byTooltip('Move earlier'), findsNothing);
    });
  });

  testWidgets('P3 shows the branch photos to the linked patient, and opens them full screen', (tester) async {
    final patients = _PatientWithPhotos();
    await pumpApp(tester, size: const Size(400, 860), extra: [
      patientRepositoryProvider.overrideWithValue(patients),
      realtimeServiceProvider.overrideWithValue(FakeRealtimeService()),
      localNotifierProvider.overrideWithValue(SilentLocalNotifier()),
    ]);
    await signIn(tester, '01000000002');
    if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);
    }
    await open(tester, '/patient/doctors/${FakePatientRepository.doctorA.id}');

    expect(find.byType(BranchPhotoStrip), findsOneWidget); // only the branch with photos
    expect(find.bySemanticsLabel('Branch photo'), findsNWidgets(2));
    expect(patients.asked, ['doc-a/br-a1/photo-1?thumb', 'doc-a/br-a1/photo-2?thumb']);

    await tester.tap(find.bySemanticsLabel('Branch photo').last);
    await settle(tester);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(patients.asked.last, 'doc-a/br-a1/photo-2');
  });
}
