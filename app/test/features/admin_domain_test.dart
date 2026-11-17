import 'package:dio/dio.dart';
import 'package:el3yada/core/format/app_format.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/admin/data/admin_repository.dart';
import 'package:el3yada/features/admin/data/fake_admin_repository.dart';
import 'package:el3yada/features/admin/data/sample_license.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart';
import 'package:el3yada/features/admin/domain/setting_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cairo time', () {
    test('winter is UTC+2, summer UTC+3', () {
      expect(AppFormat.cairo(DateTime.utc(2026, 11, 15, 10)).hour, 12);
      expect(AppFormat.cairo(DateTime.utc(2026, 7, 1, 10)).hour, 13);
    });

    test('summer time starts on the last Friday of April and ends after the last Thursday of October', () {
      // 2026: Friday 24 April 00:00 local (Thursday 22:00 UTC) to Thursday 29 October 24:00 local (21:00 UTC).
      expect(AppFormat.cairo(DateTime.utc(2026, 4, 23, 21, 59)), DateTime.utc(2026, 4, 23, 23, 59));
      expect(AppFormat.cairo(DateTime.utc(2026, 4, 23, 22)), DateTime.utc(2026, 4, 24, 1));
      expect(AppFormat.cairo(DateTime.utc(2026, 10, 29, 20, 59)), DateTime.utc(2026, 10, 29, 23, 59));
      expect(AppFormat.cairo(DateTime.utc(2026, 10, 29, 21)), DateTime.utc(2026, 10, 29, 23));
    });

    test('a Cairo day starts at 22:00 or 21:00 UTC the day before', () {
      expect(AppFormat.cairoDayStartUtc(DateTime(2026, 11, 15)), DateTime.utc(2026, 11, 14, 22));
      expect(AppFormat.cairoDayStartUtc(DateTime(2026, 7, 1)), DateTime.utc(2026, 6, 30, 21));
    });
  });

  group('money', () {
    test('piasters show as EGP with up to 2 decimals', () {
      expect(AppFormat.egpNumber(30000), '300');
      expect(AppFormat.egpNumber(15050), '150.50');
      expect(AppFormat.egpNumber(125000), '1,250');
    });

    test('typed EGP becomes piasters; anything else is refused', () {
      expect(AppFormat.parseEgp('300'), 30000);
      expect(AppFormat.parseEgp('150.5'), 15050);
      expect(AppFormat.parseEgp('1,250.75'), 125075);
      expect(AppFormat.parseEgp('٣٠'), 3000);
      expect(AppFormat.parseEgp('1.234'), isNull);
      expect(AppFormat.parseEgp('-5'), isNull);
      expect(AppFormat.parseEgp('abc'), isNull);
      expect(AppFormat.parseEgp(''), isNull);
    });
  });

  test('Egyptian numbers display as they are written locally', () {
    expect(AppFormat.phone('+201012345678'), '010 1234 5678');
    expect(AppFormat.phone('+20223581234'), '02 2358 1234');
    expect(AppFormat.phone('+20882331234'), '088 233 1234');
    expect(AppFormat.phone('19567'), '19567');
    expect(AppFormat.phone('+447700900123'), '+447700900123');
  });

  group('AD13 setting rules (the API\'s SettingFields)', () {
    SettingFieldSpec field(String name) => SettingFields.byName[name]!;

    test('every API setting is here, once', () {
      expect(SettingFields.all.map((f) => f.name).toSet(), {
        'examFeePiasters', 'consultationFeePiasters', 'gracePeriodDays', 'maxConsecutiveConsultations', //
        'trialDays', 'maxUploadMb', 'maxAssistantsPerDoctor', 'maxBranchesPerDoctor', 'instapayAddress', 'instapayAccountName',
        'instapayInstructionsAr', 'instapayInstructionsEn', 'supportPhone', 'supportWhatsapp', 'supportEmail',
        'minVersionAndroid', 'minVersionIos', 'minVersionWindows', 'minVersionMacos', 'maintenanceEnabled',
        'maintenanceMessageAr', 'maintenanceMessageEn', 'termsAr', 'termsEn', 'privacyAr', 'privacyEn',
      });
      expect(SettingFields.all, hasLength(26));
    });

    test('fees: 0 to 10,000 EGP, sent in piasters', () {
      final fee = field('examFeePiasters');
      expect(fee.check('10000'), isNull);
      expect(fee.check('10000.01'), SettingProblem.outOfRange);
      expect(fee.check(''), SettingProblem.required);
      expect(fee.check('1.234'), SettingProblem.notNumber);
      expect(fee.wire('45.5'), 4550);
      expect(fee.display(3000), '30');
      expect(fee.display(4550), '45.50');
    });

    test('whole numbers have the API ranges', () {
      expect(field('maxConsecutiveConsultations').check('0'), SettingProblem.outOfRange);
      expect(field('maxConsecutiveConsultations').check('5'), isNull);
      expect(field('gracePeriodDays').check('32'), SettingProblem.outOfRange);
      expect(field('maxUploadMb').check('200'), isNull);
      expect(field('maxBranchesPerDoctor').check('0'), SettingProblem.outOfRange);
      expect(field('maxAssistantsPerDoctor').check('0'), isNull);
      expect(field('gracePeriodDays').wire('١٠'), 10);
      // The free trial (spec 6.16): 1 to 90 days.
      expect(field('trialDays').check('0'), SettingProblem.outOfRange);
      expect(field('trialDays').check('90'), isNull);
      expect(field('trialDays').check('91'), SettingProblem.outOfRange);
      expect(field('trialDays').appliesToNewOnly, isTrue);
    });

    test('versions are major.minor.patch and required', () {
      expect(field('minVersionAndroid').check('1.2.3'), isNull);
      expect(field('minVersionAndroid').check('1.2'), SettingProblem.invalidVersion);
      expect(field('minVersionAndroid').check(''), SettingProblem.required);
    });

    test('support contacts: landlines and hotlines allowed, empty clears', () {
      final phone = field('supportPhone');
      expect(phone.check('02 2358 1234'), isNull);
      expect(phone.check('19567'), isNull);
      expect(phone.check('010 1234 5678'), isNull);
      expect(phone.check('0123'), SettingProblem.invalidPhone);
      expect(phone.wire(''), isNull);
      expect(field('supportWhatsapp').check('+447700900123'), isNull);
      expect(field('supportWhatsapp').check('12'), SettingProblem.invalidPhone);
      expect(field('supportEmail').check('help@el3yada'), SettingProblem.invalidEmail);
      expect(field('supportEmail').wire('  '), isNull);
    });

    test('texts have their length limits', () {
      expect(field('instapayAccountName').check('x' * 100), isNull);
      expect(field('instapayAccountName').check('x' * 101), SettingProblem.tooLong);
      expect(field('termsAr').check('x' * 100000), isNull);
    });
  });

  test('AD15 filters become the API query', () {
    final filter = const AuditFilter()
        .withAction('settingsUpdated')
        .withActor('u1', 'Nour')
        .withDates(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 2))
        .withTargetType('settings');
    expect(filter.toQuery(), {
      'action': 'settingsUpdated',
      'actorUserId': 'u1',
      'targetType': 'settings',
      'from': '2026-11-01T00:00:00.000Z',
      'to': '2026-11-02T00:00:00.000Z',
    });
    expect(filter.withTarget('doctor', 'd1', 'Dr. X').toQuery()['targetId'], 'd1');
    expect(const AuditFilter().isEmpty, isTrue);
    expect(filter.withActor(null, null).actorName, isNull);
  });

  group('offline admin data', () {
    test('keeps the API rules: one active super admin, no self changes', () async {
      final fake = FakeAdminRepository(delay: Duration.zero, currentAdmin: () => ('me', 'Admin', 'a@x.dev', true));
      await expectLater(fake.setAdminRole('me', AdminRole.admin), throwsA(_code('CANNOT_CHANGE_OWN_ROLE')));
      await expectLater(fake.setAdminStatus('me', active: false), throwsA(_code('CANNOT_DISABLE_SELF')));
      await fake.setAdminRole('admin-nour', AdminRole.admin);
      // Only "me" is still an active super admin; demoting another admin works,
      // but a plain admin can't manage admins at all.
      final plain = FakeAdminRepository(delay: Duration.zero, currentAdmin: () => ('me', 'Admin', 'a@x.dev', false));
      await expectLater(plain.admins(), throwsA(_code('FORBIDDEN')));
    });

    test('AD2 lists every doctor; approving a legacy sign-up starts their trial, once', () async {
      final fake = FakeAdminRepository(delay: Duration.zero);
      final before = await fake.doctorRegistrations();
      expect(before.totalCount, 8);
      expect((await fake.doctorRegistrations(trial: TrialFilter.running)).items.map((r) => r.doctorId), ['doc-tarek']);
      expect((await fake.doctorRegistrations(trial: TrialFilter.ended)).items.map((r) => r.doctorId), ['doc-nadia']);

      final approved = await fake.reviewDoctorRegistration(doctorId: 'doc-sami', decision: ReviewDecision.approve);
      expect(approved.status, DoctorStatuses.active);
      expect(approved.trial?.daysLeft, 14);
      final after = await fake.doctorRegistrations();
      expect(after.totalCount, before.totalCount, reason: 'the doctor stays, now active');
      expect(after.items.singleWhere((r) => r.doctorId == 'doc-sami').trial?.ended, isFalse);
      expect((await fake.doctorRegistrations(trial: TrialFilter.running)).totalCount, 2);
      await expectLater(
        fake.reviewDoctorRegistration(doctorId: 'doc-sami', decision: ReviewDecision.approve),
        throwsA(_code('REGISTRATION_NOT_PENDING')),
      );
    });

    test('suspends an active doctor and reactivates them, with a reason (BR-G4)', () async {
      final fake = FakeAdminRepository(delay: Duration.zero);
      await expectLater(fake.setDoctorStatus('doc-tarek', suspended: true, reason: ' ab '), throwsA(_code('REASON_REQUIRED')));

      final suspended = await fake.setDoctorStatus('doc-tarek', suspended: true, reason: ' فاتورة   أكتوبر ');
      expect(suspended.isSuspended, isTrue);
      expect(suspended.statusReason, 'فاتورة أكتوبر');
      expect(suspended.statusChangedAt, isNotNull);
      final active = await fake.setDoctorStatus('doc-tarek', suspended: false, reason: 'تم السداد');
      expect(active.status, DoctorStatuses.active);
      expect(active.statusReason, isNull);
      expect((await fake.doctorRegistration('doc-tarek')).registration.statusReason, isNull);

      // A legacy sign-up waiting for review is neither active nor suspended.
      await expectLater(
        fake.setDoctorStatus('doc-sami', suspended: true, reason: 'سبب الإيقاف'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'DOCTOR_STATUS_NOT_CHANGEABLE')
            .having((e) => e.details['status'], 'status', DoctorStatuses.pendingApproval)),
      );
      final audit = await fake.auditLogs(const AuditFilter(), pageSize: 100);
      expect(audit.items.map((e) => e.action), containsAll(['doctorSuspended', 'doctorReactivated']));
    });

    test('settings history only records real changes', () async {
      final fake = FakeAdminRepository(delay: Duration.zero);
      final before = (await fake.settingsHistory()).totalCount;
      await fake.updateSettings({'examFeePiasters': 3000, 'gracePeriodDays': 9});
      final history = await fake.settingsHistory();
      expect(history.totalCount, before + 1);
      expect(history.items.first.field, 'gracePeriodDays');
      expect(history.items.first.before, '7');
      expect(history.items.first.after, '9');
    });
  });

  test('setDoctorStatus sends the status and the reason, and reads the answer', () async {
    final sent = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        sent.add(options);
        handler.resolve(Response(requestOptions: options, statusCode: 200, data: <String, dynamic>{
          'doctorId': 'd1',
          'fullName': 'سامي عبد الله',
          'status': 'suspended',
          'statusReason': 'فاتورة أكتوبر',
          'statusChangedAt': '2026-11-16T10:00:00.000Z',
        }));
      }));

    final view = await ApiAdminRepository(dio).setDoctorStatus('d1', suspended: true, reason: 'فاتورة أكتوبر');

    expect(sent.single.path, '/admin/setDoctorStatus');
    expect(sent.single.data, {'doctorId': 'd1', 'status': 'suspended', 'reason': 'فاتورة أكتوبر'});
    expect(view.doctorId, 'd1');
    expect(view.fullName, 'سامي عبد الله');
    expect(view.isSuspended, isTrue);
    expect(view.statusReason, 'فاتورة أكتوبر');
    expect(view.statusChangedAt, DateTime.utc(2026, 11, 16, 10));
  });

  test('sample license files are a real PNG and a real PDF', () {
    final png = SampleLicense.png();
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final pdf = String.fromCharCodes(SampleLicense.pdf(name: 'Sami', number: '45678'));
    expect(pdf, startsWith('%PDF-1.4'));
    expect(pdf, contains('Syndicate number: 45678'));
    expect(pdf.trimRight(), endsWith('%%EOF'));
  });
}

Matcher _code(String code) => predicate((Object? e) => e.toString().contains(code), 'ApiException $code');
