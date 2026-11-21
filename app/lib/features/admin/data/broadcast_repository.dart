import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/data/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';

/// Who gets a broadcast (backend/docs/api-broadcast.md).
enum BroadcastAudience { all, selected }

/// AD16's form, as `sendBroadcast` takes it. A language is written whole
/// (title and body) or left out; the API fills an empty one from the other.
class BroadcastDraft {
  const BroadcastDraft({
    required this.audience,
    this.doctorIds = const [],
    this.titleAr = '',
    this.bodyAr = '',
    this.titleEn = '',
    this.bodyEn = '',
  });

  static const maxTitle = 100;
  static const maxBody = 500;

  final BroadcastAudience audience;
  final List<String> doctorIds;
  final String titleAr;
  final String bodyAr;
  final String titleEn;
  final String bodyEn;

  Map<String, dynamic> toJson() {
    String? text(String value) => value.trim().isEmpty ? null : value.trim();
    return {
      'audience': audience.name,
      if (audience == BroadcastAudience.selected) 'doctorIds': doctorIds,
      'titleAr': ?text(titleAr),
      'bodyAr': ?text(bodyAr),
      'titleEn': ?text(titleEn),
      'bodyEn': ?text(bodyEn),
    };
  }

  /// The API's field rules, by field name (`REQUIRED`, `TOO_LONG`); empty
  /// when it can be sent. Same order and codes as the server.
  Map<String, String> validate() {
    final errors = <String, String>{};
    bool has(String value) => value.trim().isNotEmpty;
    if (audience == BroadcastAudience.selected && doctorIds.isEmpty) errors['doctorIds'] = 'REQUIRED';
    if (!has(titleAr) && !has(bodyAr) && !has(titleEn) && !has(bodyEn)) {
      errors['titleAr'] = 'REQUIRED';
      return errors;
    }
    for (final (title, body, titleKey, bodyKey) in [
      (titleAr, bodyAr, 'titleAr', 'bodyAr'),
      (titleEn, bodyEn, 'titleEn', 'bodyEn'),
    ]) {
      if (has(body) && !has(title)) errors[titleKey] = 'REQUIRED';
      if (has(title) && !has(body)) errors[bodyKey] = 'REQUIRED';
      if (title.trim().length > maxTitle) errors[titleKey] = 'TOO_LONG';
      if (body.trim().length > maxBody) errors[bodyKey] = 'TOO_LONG';
    }
    return errors;
  }
}

/// A sent broadcast (the API reads it back from its audit row).
class BroadcastEntry {
  const BroadcastEntry({
    required this.broadcastId,
    required this.sentAt,
    required this.audience,
    required this.recipients,
    required this.titleAr,
    required this.bodyAr,
    required this.titleEn,
    required this.bodyEn,
    this.sentByName,
  });

  factory BroadcastEntry.fromJson(Map<String, dynamic> json) => BroadcastEntry(
        broadcastId: json['broadcastId'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String).toUtc(),
        audience: json['audience'] == 'selected' ? BroadcastAudience.selected : BroadcastAudience.all,
        recipients: (json['recipients'] as num?)?.toInt() ?? 0,
        sentByName: (json['sentBy'] as Map?)?['displayName'] as String?,
        titleAr: json['titleAr'] as String? ?? '',
        bodyAr: json['bodyAr'] as String? ?? '',
        titleEn: json['titleEn'] as String? ?? '',
        bodyEn: json['bodyEn'] as String? ?? '',
      );

  final String broadcastId;
  final DateTime sentAt;
  final BroadcastAudience audience;
  final int recipients;
  final String? sentByName;
  final String titleAr;
  final String bodyAr;
  final String titleEn;
  final String bodyEn;

  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;
  String body(String languageCode) => languageCode == 'ar' ? bodyAr : bodyEn;
}

/// AD16 (backend/docs/api-broadcast.md). Every method throws [ApiException].
abstract interface class BroadcastRepository {
  /// `POST /api/admin/sendBroadcast`. 409 `BROADCAST_NO_RECIPIENTS` when no
  /// chosen doctor can receive it; field errors as in [BroadcastDraft.validate].
  Future<BroadcastEntry> send(BroadcastDraft draft);

  /// `GET /api/admin/broadcasts`: the broadcasts sent, newest first.
  Future<Paged<BroadcastEntry>> history({int page = 1, int pageSize = 25});
}

final broadcastRepositoryProvider = Provider<BroadcastRepository>((ref) {
  if (Env.useFakeAuth) {
    return FakeBroadcastRepository(senderName: () => ref.read(authControllerProvider).value?.displayName);
  }
  return ApiBroadcastRepository(ref.watch(dioProvider));
});

class ApiBroadcastRepository implements BroadcastRepository {
  ApiBroadcastRepository(this._dio);

  final Dio _dio;

  @override
  Future<BroadcastEntry> send(BroadcastDraft draft) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/admin/sendBroadcast', data: draft.toJson());
      return BroadcastEntry.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<Paged<BroadcastEntry>> history({int page = 1, int pageSize = 25}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/admin/broadcasts', queryParameters: {'page': page, 'pageSize': pageSize});
      return Paged.fromJson(response.data ?? const {}, BroadcastEntry.fromJson);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Offline AD16 with the API's rules: field errors, the language fallback,
/// newest first. "All" reaches [allDoctors] doctors; chosen doctors all
/// receive it except those in [cannotReceive] (pending, rejected or disabled).
class FakeBroadcastRepository implements BroadcastRepository {
  FakeBroadcastRepository({this.delay = const Duration(milliseconds: 400), this.allDoctors = 12, this.senderName});

  final Duration delay;
  final int allDoctors;
  final String? Function()? senderName;

  /// Doctor ids that can't receive a broadcast (for tests).
  final cannotReceive = <String>{};

  /// What [send] was given (for tests).
  final sent = <BroadcastDraft>[];

  final _history = <BroadcastEntry>[];
  int _next = 1;

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<BroadcastEntry> send(BroadcastDraft draft) async {
    await _wait();
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw ApiException(kind: ApiErrorKind.http, status: 400, code: ApiCodes.validationFailed, fieldCodes: errors);
    }
    final recipients = draft.audience == BroadcastAudience.all
        ? allDoctors
        : draft.doctorIds.where((id) => !cannotReceive.contains(id)).length;
    if (recipients == 0) throw const ApiException(kind: ApiErrorKind.http, status: 409, code: 'BROADCAST_NO_RECIPIENTS');
    String pick(String value, String other) => value.trim().isEmpty ? other.trim() : value.trim();
    final entry = BroadcastEntry(
      broadcastId: 'broadcast-${_next++}',
      sentAt: DateTime.now().toUtc(),
      audience: draft.audience,
      recipients: recipients,
      sentByName: senderName?.call() ?? 'Admin',
      titleAr: pick(draft.titleAr, draft.titleEn),
      bodyAr: pick(draft.bodyAr, draft.bodyEn),
      titleEn: pick(draft.titleEn, draft.titleAr),
      bodyEn: pick(draft.bodyEn, draft.bodyAr),
    );
    sent.add(draft);
    _history.insert(0, entry);
    return entry;
  }

  @override
  Future<Paged<BroadcastEntry>> history({int page = 1, int pageSize = 25}) async {
    await _wait();
    final start = ((page - 1) * pageSize).clamp(0, _history.length);
    final end = (start + pageSize).clamp(0, _history.length);
    return Paged(
      items: _history.sublist(start, end),
      page: page,
      pageSize: pageSize,
      totalCount: _history.length,
      totalPages: _history.isEmpty ? 0 : (_history.length / pageSize).ceil(),
    );
  }
}
