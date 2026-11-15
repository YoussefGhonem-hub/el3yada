import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:el3yada/features/clinic/application/clinic_providers.dart';
import 'package:el3yada/features/clinic/domain/clinic_context.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// The example of `GET /api/clinic/me` in backend/docs/api-phase-2.md.
Map<String, dynamic> clinicJson({String status = 'active', bool assistant = true}) => {
      'role': assistant ? 'assistant' : 'doctor',
      'doctor': {
        'id': 'd1', 'fullName': 'أحمد علي', 'fullNameEn': 'Ahmed Ali', 'title': 'أخصائي', 'titleEn': null,
        'specialtyId': 's1', 'specialtyNameAr': 'باطنة', 'specialtyNameEn': 'Internal medicine', 'status': status,
      },
      'assistant': assistant
          ? {'userId': 'a1', 'fullName': 'سارة محمود', 'preset': 'reception', 'allBranches': false, 'branchIds': ['b1']}
          : null,
      'permissions': {for (final key in ClinicPermission.all) key: AssistantPreset.permissions['reception']!.contains(key)},
      'branches': [
        {'id': 'b1', 'nameAr': 'فرع المعادي', 'nameEn': null, 'isDefault': true, 'status': 'active', 'governorate': 'القاهرة', 'city': 'المعادي', 'assigned': true},
        {'id': 'b2', 'nameAr': 'فرع مدينة نصر', 'nameEn': 'Nasr City', 'isDefault': false, 'status': 'active', 'governorate': 'القاهرة', 'city': 'مدينة نصر', 'assigned': false},
        {'id': 'b3', 'nameAr': 'فرع قديم', 'nameEn': null, 'isDefault': false, 'status': 'archived', 'governorate': 'الجيزة', 'city': 'الدقي', 'assigned': true},
      ],
      'defaultBranchId': 'b1',
      'fees': {'examinationFeePiasters': 3000, 'consultationFeePiasters': 1500, 'maxConsecutiveConsultations': 2},
      'limits': {'maxAssistants': 5, 'maxBranches': 5, 'maxUploadMb': 50},
    };

void main() {
  group('ClinicContext', () {
    test('reads clinic/me', () {
      final clinic = ClinicContext.fromJson(clinicJson());

      expect(clinic.role, UserRole.assistant);
      expect(clinic.isDoctor, isFalse);
      expect(clinic.doctor.name('en'), 'Ahmed Ali');
      expect(clinic.doctor.name('ar'), 'أحمد علي');
      expect(clinic.assistant!.branchIds, ['b1']);
      expect(clinic.can(ClinicPermission.patientsManage), isTrue);
      expect(clinic.can(ClinicPermission.clinicalView), isFalse);
      expect(clinic.canPay, isFalse);
      expect(clinic.fees.examinationFeePiasters, 3000);
      expect(clinic.limits.maxUploadMb, 50);
      expect(clinic.isSuspended, isFalse);
    });

    test('work branches are the assigned ones that are not archived', () {
      final clinic = ClinicContext.fromJson(clinicJson());
      expect(clinic.workBranches.map((b) => b.id), ['b1']);
      expect(clinic.branch('b2')!.name('en'), 'Nasr City');
      expect(clinic.branch('b1')!.name('en'), 'فرع المعادي');
    });

    test('a doctor can do everything; suspension is the doctor status', () {
      final clinic = ClinicContext.fromJson(clinicJson(assistant: false, status: 'suspended'));
      expect(clinic.isDoctor, isTrue);
      expect(clinic.assistant, isNull);
      expect(clinic.can(ClinicPermission.revenueView), isTrue);
      expect(clinic.isSuspended, isTrue);
      expect(clinic.canPay, isTrue);
    });
  });

  group('permissions', () {
    test('switching one on switches on what it needs, in chains', () {
      expect(
        ClinicPermission.toggle({}, ClinicPermission.scheduleManage, on: true),
        {ClinicPermission.scheduleManage, ClinicPermission.appointmentsManage, ClinicPermission.appointmentsView},
      );
    });

    test('switching one off switches off what needs it', () {
      final all = AssistantPreset.permissions[AssistantPreset.officeManager]!;
      final result = ClinicPermission.toggle(all, ClinicPermission.appointmentsView, on: false);
      expect(result.contains(ClinicPermission.appointmentsManage), isFalse);
      expect(result.contains(ClinicPermission.scheduleManage), isFalse);
      expect(result.contains(ClinicPermission.billingPay), isTrue);
    });

    test('a preset is matched, and any change makes it custom', () {
      final reception = AssistantPreset.permissions[AssistantPreset.reception]!;
      expect(AssistantPreset.match(reception), AssistantPreset.reception);
      expect(AssistantPreset.match({...reception, ClinicPermission.chat}), AssistantPreset.custom);
    });

    test('the presets agree with their dependencies', () {
      for (final keys in AssistantPreset.permissions.values) {
        for (final key in keys) {
          expect(ClinicPermission.toggle(keys, key, on: true), keys, reason: key);
        }
      }
    });
  });

  group('current branch', () {
    final doctor = ClinicContext.fromJson({
      ...clinicJson(assistant: false),
      'branches': [
        for (final b in clinicJson()['branches'] as List) {...(b as Map<String, dynamic>), 'assigned': true},
      ],
    });

    test('the saved branch while it is still a work branch', () {
      expect(CurrentBranchController.pick(doctor, 'b2')!.id, 'b2');
    });

    test('else the default branch, never an archived one', () {
      expect(CurrentBranchController.pick(doctor, 'b3')!.id, 'b1');
      expect(CurrentBranchController.pick(doctor, null)!.id, 'b1');
    });

    test("an assistant can't pick a branch they don't work in", () {
      final assistant = ClinicContext.fromJson(clinicJson());
      expect(CurrentBranchController.pick(assistant, 'b2')!.id, 'b1');
    });
  });
}
