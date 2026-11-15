import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/settings/app_settings.dart';

/// `GET /api/settings/public`: what the app reads before sign-in (A1 version
/// and maintenance checks, A11–A13, support contact on A6, A7 and A10).
class PublicSettings {
  const PublicSettings({
    this.minAppVersion = const {},
    this.maintenanceEnabled = false,
    this.maintenanceMessageAr,
    this.maintenanceMessageEn,
    this.supportPhone,
    this.supportWhatsapp,
    this.supportEmail,
    this.terms = const LegalText(),
    this.privacy = const LegalText(),
  });

  factory PublicSettings.fromJson(Map<String, dynamic> json) {
    final versions = (json['minAppVersion'] as Map?)?.cast<String, dynamic>() ?? const {};
    final maintenance = (json['maintenance'] as Map?)?.cast<String, dynamic>() ?? const {};
    final support = (json['support'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PublicSettings(
      minAppVersion: {
        for (final entry in versions.entries)
          if (entry.value is String && (entry.value as String).isNotEmpty) entry.key: entry.value as String,
      },
      maintenanceEnabled: maintenance['enabled'] == true,
      maintenanceMessageAr: maintenance['messageAr'] as String?,
      maintenanceMessageEn: maintenance['messageEn'] as String?,
      supportPhone: support['phone'] as String?,
      supportWhatsapp: support['whatsapp'] as String?,
      supportEmail: support['email'] as String?,
      terms: LegalText.fromJson((json['terms'] as Map?)?.cast<String, dynamic>()),
      privacy: LegalText.fromJson((json['privacy'] as Map?)?.cast<String, dynamic>()),
    );
  }

  /// By platform: `android`, `ios`, `windows`, `macos`.
  final Map<String, String> minAppVersion;
  final bool maintenanceEnabled;
  final String? maintenanceMessageAr;
  final String? maintenanceMessageEn;
  final String? supportPhone;
  final String? supportWhatsapp;
  final String? supportEmail;
  final LegalText terms;
  final LegalText privacy;

  bool get hasSupportContact => supportPhone != null || supportWhatsapp != null || supportEmail != null;

  String? maintenanceMessage(String languageCode) =>
      _nonEmpty(languageCode == 'ar' ? maintenanceMessageAr : maintenanceMessageEn) ??
      _nonEmpty(maintenanceMessageAr) ??
      _nonEmpty(maintenanceMessageEn);

  /// True when [appVersion] is older than the minimum set for [platform].
  bool requiresUpdate(String? platform, String appVersion) {
    final minimum = platform == null ? null : minAppVersion[platform];
    if (minimum == null) return false;
    return compareVersions(appVersion, minimum) < 0;
  }

  /// Compares `1.2.10` with `1.2.9` part by part. Build numbers (`+5`) and
  /// pre-release tags (`-beta`) are ignored.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.split(RegExp('[+-]')).first.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < 3; i++) {
      final left = i < x.length ? x[i] : 0;
      final right = i < y.length ? y[i] : 0;
      if (left != right) return left.compareTo(right);
    }
    return 0;
  }
}

/// The Terms or the Privacy Policy (A12), in both languages.
class LegalText {
  const LegalText({this.version, this.ar, this.en, this.updatedAt});

  factory LegalText.fromJson(Map<String, dynamic>? json) => json == null
      ? const LegalText()
      : LegalText(
          version: json['version'] as String?,
          ar: json['ar'] as String?,
          en: json['en'] as String?,
          updatedAt: DateTime.tryParse('${json['updatedAt']}'),
        );

  final String? version;
  final String? ar;
  final String? en;
  final DateTime? updatedAt;

  /// The text in [languageCode], or the other language if that one is empty.
  String? textFor(String languageCode) =>
      _nonEmpty(languageCode == 'ar' ? ar : en) ?? _nonEmpty(ar) ?? _nonEmpty(en);
}

String? _nonEmpty(String? value) => (value == null || value.trim().isEmpty) ? null : value;

abstract interface class PublicSettingsRepository {
  /// Fresh from the API. Throws [ApiException].
  Future<PublicSettings> fetch();

  /// The last copy fetched, for offline use (support contact, Terms).
  PublicSettings? cached();
}

class ApiPublicSettingsRepository implements PublicSettingsRepository {
  ApiPublicSettingsRepository(this._dio, this._cache);

  static const _cacheKey = 'cache.publicSettings';

  final Dio _dio;
  final SharedPreferencesLike _cache;

  @override
  Future<PublicSettings> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/settings/public');
      final data = response.data ?? const {};
      await _cache.setString(_cacheKey, jsonEncode(data));
      return PublicSettings.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  PublicSettings? cached() {
    final raw = _cache.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return PublicSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }
}

/// The two SharedPreferences methods the cache uses, so tests can fake them.
abstract interface class SharedPreferencesLike {
  String? getString(String key);
  Future<bool> setString(String key, String value);
}

class _Prefs implements SharedPreferencesLike {
  _Prefs(this._ref);

  final Ref _ref;

  @override
  String? getString(String key) => _ref.read(sharedPreferencesProvider).getString(key);

  @override
  Future<bool> setString(String key, String value) => _ref.read(sharedPreferencesProvider).setString(key, value);
}

final publicSettingsRepositoryProvider = Provider<PublicSettingsRepository>(
  (ref) => ApiPublicSettingsRepository(ref.watch(plainDioProvider), _Prefs(ref)),
);
