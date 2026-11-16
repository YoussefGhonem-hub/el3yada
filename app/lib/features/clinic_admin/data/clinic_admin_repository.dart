import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/account_models.dart';
import '../domain/activity_models.dart';
import '../domain/assistant_models.dart';
import '../domain/branch_models.dart';
import '../domain/json_read.dart';
import '../domain/price_models.dart';
import 'fake_clinic_admin_repository.dart';

/// Error codes of the clinic admin endpoints that screens react to
/// (backend/docs/api-phase-2-clinic.md, "Error codes").
abstract final class ClinicAdminCodes {
  static const branchLimitReached = 'BRANCH_LIMIT_REACHED';
  static const cannotArchiveDefaultBranch = 'CANNOT_ARCHIVE_DEFAULT_BRANCH';
  static const lastActiveBranch = 'LAST_ACTIVE_BRANCH';
  static const branchHasBookings = 'BRANCH_HAS_BOOKINGS';
  static const branchNotActive = 'BRANCH_NOT_ACTIVE';
  static const assistantLimitReached = 'ASSISTANT_LIMIT_REACHED';
  static const assistantPhoneTaken = 'ASSISTANT_PHONE_TAKEN';
  static const assistantRemoved = 'ASSISTANT_REMOVED';
}

/// `BRANCH_HAS_BOOKINGS` (BR-BR9): the bookings that stop a closure or an
/// archive, earliest first (at most 100 of [totalCount]). [details] is the
/// whole answer, as for any [ApiException].
class BranchHasBookingsException extends ApiException {
  const BranchHasBookingsException({required this.bookings, required this.totalCount, super.cause, super.details})
      : super(kind: ApiErrorKind.http, status: 409, code: ClinicAdminCodes.branchHasBookings);

  final List<BranchBooking> bookings;
  final int totalCount;
}

/// The clinic's own admin endpoints: branches (D28, D29), visit prices
/// (D37, AS19), the doctor's profile (D22), notification preferences (D24,
/// AS12), assistants (D25, D26) and the activity log (D27). Every method
/// throws [ApiException].
abstract interface class ClinicAdminRepository {
  /// D28: every branch, the default first, archived ones last.
  Future<BranchList> branches();

  /// D29.
  Future<BranchDetails> branch(String branchId);

  /// D29 "new". Working hours and prices are set afterwards.
  Future<BranchDetails> createBranch({
    required BranchInfo info,
    required BranchAddress address,
    required BranchContact contact,
    BranchChecklistInput? clinicInfo,
  });

  /// One D29 tab (or several): a group that is sent replaces that group.
  Future<BranchDetails> updateBranch(
    String branchId, {
    BranchInfo? info,
    BranchAddress? address,
    BranchContact? contact,
    BranchChecklistInput? clinicInfo,
  });

  /// Replaces the whole week.
  Future<BranchDetails> updateBranchHours(String branchId, List<BranchPeriod> periods);

  /// Throws [BranchHasBookingsException] for `BRANCH_HAS_BOOKINGS`.
  Future<BranchDetails> setBranchStatus(String branchId, String status, {String? closedMessage, DateTime? reopenDate});

  Future<BranchDetails> setDefaultBranch(String branchId);

  /// D37 with a page of the history.
  Future<PricesOverview> prices({int page = 1, int pageSize = 25});

  /// [branchId] null: the doctor's prices. Both prices are replaced; null is
  /// "not set" (doctor) or "use the doctor's" (branch).
  Future<PricesOverview> updatePrices({String? branchId, int? examinationPricePiasters, int? consultationPricePiasters});

  Future<DoctorProfile> doctorProfile();

  Future<DoctorProfile> updateDoctorProfile(DoctorProfileUpdate update);

  Future<NotificationPrefs> notificationPrefs();

  /// Only the values passed change.
  Future<NotificationPrefs> updateNotificationPrefs({bool? chat, bool? reminders, bool? showPreview, bool? bookings});

  Future<AssistantList> assistants({bool includeRemoved = false});

  Future<Assistant> assistant(String assistantId);

  Future<AssistantWithPassword> createAssistant(AssistantDraft draft);

  /// Only the parts passed change. [permissions] is the whole set.
  Future<Assistant> updateAssistant(
    String assistantId, {
    String? fullName,
    String? phone,
    bool? allBranches,
    Set<String>? branchIds,
    Set<String>? permissions,
  });

  Future<AssistantWithPassword> resetAssistantPassword(String assistantId);

  /// `active`, `disabled` or `removed` (final).
  Future<Assistant> setAssistantStatus(String assistantId, String status);

  /// D27, newest first.
  Future<ActivityPage> activity(ActivityFilter filter, {int page = 1, int pageSize = 25});
}

/// Real API, or the offline clinic when `USE_FAKE_AUTH` is on (dev builds
/// and tests). The fake keeps its data for the app's lifetime, so changes
/// survive signing out and in as another clinic account.
final clinicAdminRepositoryProvider = Provider<ClinicAdminRepository>((ref) {
  if (Env.useFakeAuth) return FakeClinicAdminRepository(currentSession: () => ref.read(authControllerProvider).value);
  return ApiClinicAdminRepository(ref.watch(dioProvider));
});

/// Talks to the ASP.NET Core API.
class ApiClinicAdminRepository implements ClinicAdminRepository {
  ApiClinicAdminRepository(this._dio);

  final Dio _dio;

  @override
  Future<BranchList> branches() => _call(() async => BranchList.fromJson(await _get('/branches')));

  @override
  Future<BranchDetails> branch(String branchId) => _call(() async => BranchDetails.fromJson(await _get('/branches/$branchId')));

  @override
  Future<BranchDetails> createBranch({
    required BranchInfo info,
    required BranchAddress address,
    required BranchContact contact,
    BranchChecklistInput? clinicInfo,
  }) =>
      _call(() async => BranchDetails.fromJson(await _post('/branches/createBranch', {
            'info': info.toJson(),
            'address': address.toJson(),
            'contact': contact.toJson(),
            'clinicInfo': ?clinicInfo?.toJson(),
          })));

  @override
  Future<BranchDetails> updateBranch(
    String branchId, {
    BranchInfo? info,
    BranchAddress? address,
    BranchContact? contact,
    BranchChecklistInput? clinicInfo,
  }) =>
      _call(() async => BranchDetails.fromJson(await _post('/branches/updateBranch', {
            'branchId': branchId,
            'info': ?info?.toJson(),
            'address': ?address?.toJson(),
            'contact': ?contact?.toJson(),
            'clinicInfo': ?clinicInfo?.toJson(),
          })));

  @override
  Future<BranchDetails> updateBranchHours(String branchId, List<BranchPeriod> periods) =>
      _call(() async => BranchDetails.fromJson(await _post('/branches/updateBranchHours', {
            'branchId': branchId,
            'periods': [for (final period in periods) period.toJson()],
          })));

  @override
  Future<BranchDetails> setBranchStatus(String branchId, String status, {String? closedMessage, DateTime? reopenDate}) =>
      _call(() async => BranchDetails.fromJson(await _post('/branches/setBranchStatus', {
            'branchId': branchId,
            'status': status,
            'closedMessage': ?closedMessage,
            if (reopenDate != null) 'reopenDate': writeDay(reopenDate),
          })));

  @override
  Future<BranchDetails> setDefaultBranch(String branchId) =>
      _call(() async => BranchDetails.fromJson(await _post('/branches/setDefaultBranch', {'branchId': branchId})));

  @override
  Future<PricesOverview> prices({int page = 1, int pageSize = 25}) =>
      _call(() async => PricesOverview.fromJson(await _get('/prices', {'page': page, 'pageSize': pageSize})));

  @override
  Future<PricesOverview> updatePrices({String? branchId, int? examinationPricePiasters, int? consultationPricePiasters}) =>
      _call(() async => PricesOverview.fromJson(await _post('/prices/updatePrices', {
            'branchId': branchId,
            'examinationPricePiasters': examinationPricePiasters,
            'consultationPricePiasters': consultationPricePiasters,
          })));

  @override
  Future<DoctorProfile> doctorProfile() => _call(() async => DoctorProfile.fromJson(await _get('/doctor/profile')));

  @override
  Future<DoctorProfile> updateDoctorProfile(DoctorProfileUpdate update) =>
      _call(() async => DoctorProfile.fromJson(await _post('/doctor/updateProfile', update.toJson())));

  @override
  Future<NotificationPrefs> notificationPrefs() =>
      _call(() async => NotificationPrefs.fromJson(await _get('/me/notificationPrefs')));

  @override
  Future<NotificationPrefs> updateNotificationPrefs({bool? chat, bool? reminders, bool? showPreview, bool? bookings}) =>
      _call(() async => NotificationPrefs.fromJson(await _post('/me/updateNotificationPrefs', {
            'chat': ?chat,
            'reminders': ?reminders,
            'showPreview': ?showPreview,
            'bookings': ?bookings,
          })));

  @override
  Future<AssistantList> assistants({bool includeRemoved = false}) => _call(
      () async => AssistantList.fromJson(await _get('/assistants', {if (includeRemoved) 'includeRemoved': true})));

  @override
  Future<Assistant> assistant(String assistantId) =>
      _call(() async => Assistant.fromJson(await _get('/assistants/$assistantId')));

  @override
  Future<AssistantWithPassword> createAssistant(AssistantDraft draft) =>
      _call(() async => AssistantWithPassword.fromJson(await _post('/assistants/createAssistant', draft.toCreateJson())));

  @override
  Future<Assistant> updateAssistant(
    String assistantId, {
    String? fullName,
    String? phone,
    bool? allBranches,
    Set<String>? branchIds,
    Set<String>? permissions,
  }) =>
      _call(() async => Assistant.fromJson(await _post('/assistants/updateAssistant', {
            'assistantId': assistantId,
            'fullName': ?fullName,
            'phone': ?phone,
            'allBranches': ?allBranches,
            if (branchIds != null) 'branchIds': branchIds.toList(),
            if (permissions != null) 'permissions': AssistantDraft.permissionMapOf(permissions),
          })));

  @override
  Future<AssistantWithPassword> resetAssistantPassword(String assistantId) => _call(() async =>
      AssistantWithPassword.fromJson(await _post('/assistants/resetAssistantPassword', {'assistantId': assistantId})));

  @override
  Future<Assistant> setAssistantStatus(String assistantId, String status) => _call(() async =>
      Assistant.fromJson(await _post('/assistants/setAssistantStatus', {'assistantId': assistantId, 'status': status})));

  @override
  Future<ActivityPage> activity(ActivityFilter filter, {int page = 1, int pageSize = 25}) => _call(() async =>
      ActivityPage.fromJson(await _get('/clinic/activity', {...filter.toQuery(), 'page': page, 'pageSize': pageSize})));

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: body);
    return response.data ?? const {};
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['code'] == ClinicAdminCodes.branchHasBookings) {
        throw BranchHasBookingsException(
          bookings: [for (final row in readList(data['bookings'])) BranchBooking.fromJson(row)],
          totalCount: data['totalCount'] as int? ?? 0,
          cause: error,
          details: data.cast<String, Object?>(),
        );
      }
      throw ApiException.fromDio(error);
    }
  }
}
