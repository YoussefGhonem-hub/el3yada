import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../domain/clinic_context.dart';
import '../domain/clinic_permissions.dart';

/// The clinic the signed-in doctor or assistant works in.
abstract interface class ClinicRepository {
  /// `GET /api/clinic/me`.
  Future<ClinicContext> me();
}

class ApiClinicRepository implements ClinicRepository {
  ApiClinicRepository(this._dio);

  final Dio _dio;

  @override
  Future<ClinicContext> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/clinic/me');
      return ClinicContext.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// The offline clinic for `config/dev-offline.json` and tests: two branches,
/// with the assistant accounts of `FakeAuthRepository` as presets
/// (`+201000000001` reception in one branch, `+201000000005` office
/// manager in every branch, anyone else clinical in every branch).
class FakeClinicRepository implements ClinicRepository {
  FakeClinicRepository(this.session, {this.delay = const Duration(milliseconds: 300)});

  final AuthSession? session;
  final Duration delay;

  static const maadiBranchId = 'dev-branch-maadi';
  static const nasrCityBranchId = 'dev-branch-nasr-city';

  @override
  Future<ClinicContext> me() async {
    await Future<void>.delayed(delay);
    final session = this.session;
    if (session == null || session.role != UserRole.doctor && session.role != UserRole.assistant) {
      throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.forbidden);
    }
    return contextFor(session);
  }

  static ClinicContext contextFor(AuthSession session) {
    final isDoctor = session.role == UserRole.doctor;
    final preset = switch (session.phone) {
      '+201000000001' => AssistantPreset.reception,
      '+201000000005' => AssistantPreset.officeManager,
      _ => AssistantPreset.clinical,
    };
    final onlyMaadi = !isDoctor && preset == AssistantPreset.reception;
    return ClinicContext(
      role: session.role,
      doctor: ClinicDoctor(
        id: session.doctorId ?? 'dev-doctor',
        fullName: isDoctor ? session.displayName.replaceFirst('د. ', '') : 'تجريبي',
        fullNameEn: null,
        title: 'أخصائي',
        titleEn: null,
        specialtyId: 'dev-specialty-internal',
        specialtyNameAr: 'باطنة',
        specialtyNameEn: 'Internal medicine',
        status: session.doctorStatus == DoctorStatus.suspended ? 'suspended' : 'active',
      ),
      assistant: isDoctor
          ? null
          : ClinicAssistant(
              userId: session.userId,
              fullName: session.displayName,
              preset: preset,
              allBranches: !onlyMaadi,
              branchIds: onlyMaadi ? const [maadiBranchId] : const [],
            ),
      permissions: isDoctor ? ClinicPermission.all.toSet() : AssistantPreset.permissions[preset]!,
      branches: [
        const ClinicBranch(
          id: maadiBranchId, nameAr: 'فرع المعادي', nameEn: 'Maadi', isDefault: true, status: 'active',
          governorate: 'القاهرة', city: 'المعادي', assigned: true,
        ),
        ClinicBranch(
          id: nasrCityBranchId, nameAr: 'فرع مدينة نصر', nameEn: 'Nasr City', isDefault: false, status: 'active',
          governorate: 'القاهرة', city: 'مدينة نصر', assigned: !onlyMaadi,
        ),
      ],
      defaultBranchId: maadiBranchId,
      fees: const ClinicFees(examinationFeePiasters: 3000, consultationFeePiasters: 1500, maxConsecutiveConsultations: 2),
      limits: const ClinicLimits(maxAssistants: 5, maxBranches: 5, maxUploadMb: 50),
    );
  }
}

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  if (Env.useFakeAuth) return FakeClinicRepository(ref.watch(authControllerProvider).value);
  return ApiClinicRepository(ref.watch(dioProvider));
});
