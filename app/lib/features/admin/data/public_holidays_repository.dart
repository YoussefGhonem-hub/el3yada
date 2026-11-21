import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// A public holiday on AD13's list [C] (BR-AP13): clinics see the coming
/// ones as suggestions in D29's Special dates; none closes a branch by itself.
class PublicHoliday {
  const PublicHoliday({required this.id, required this.date, required this.nameAr, required this.nameEn});

  factory PublicHoliday.fromJson(Map<String, dynamic> json) => PublicHoliday(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
      );

  final String id;

  /// A Cairo calendar day.
  final DateTime date;
  final String nameAr;
  final String nameEn;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

/// `PUBLIC_HOLIDAY_EXISTS`: one holiday a date.
const publicHolidayExists = 'PUBLIC_HOLIDAY_EXISTS';

/// AD13's public holidays (backend/docs/api-phase-6-schedule.md, "Public
/// holidays"). Admins only. Every method throws [ApiException].
abstract interface class PublicHolidaysRepository {
  /// From a month ago on, earliest first.
  Future<List<PublicHoliday>> list();

  Future<PublicHoliday> create({required DateTime date, required String nameAr, required String nameEn});

  Future<void> delete(String id);
}

final publicHolidaysRepositoryProvider = Provider<PublicHolidaysRepository>((ref) {
  if (Env.useFakeAuth) return FakePublicHolidaysRepository();
  return ApiPublicHolidaysRepository(ref.watch(dioProvider));
});

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ApiPublicHolidaysRepository implements PublicHolidaysRepository {
  ApiPublicHolidaysRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<List<PublicHoliday>> list() => _call(() async {
        final response = await _dio.get<List<dynamic>>('/admin/publicHolidays');
        return [for (final row in response.data ?? const []) PublicHoliday.fromJson((row as Map).cast<String, dynamic>())];
      });

  @override
  Future<PublicHoliday> create({required DateTime date, required String nameAr, required String nameEn}) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>('/admin/createPublicHoliday',
            data: {'date': _day(date), 'nameAr': nameAr, 'nameEn': nameEn});
        return PublicHoliday.fromJson(response.data ?? const {});
      });

  @override
  Future<void> delete(String id) => _call(() async {
        await _dio.post<void>('/admin/deletePublicHoliday', data: {'id': id});
      });
}

/// The offline list, with the API's rules: names required (≤ 100), one
/// holiday a date. Starts with two coming holidays.
class FakePublicHolidaysRepository implements PublicHolidaysRepository {
  FakePublicHolidaysRepository({DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    _items.addAll([
      PublicHoliday(id: 'holiday-1', date: day.add(const Duration(days: 9)), nameAr: 'عيد تحرير سيناء', nameEn: 'Sinai Liberation Day'),
      PublicHoliday(id: 'holiday-2', date: day.add(const Duration(days: 30)), nameAr: 'عيد العمال', nameEn: 'Labour Day'),
    ]);
  }

  final _items = <PublicHoliday>[];
  int _next = 3;

  /// The coming year's holidays, as the clinic's schedule lists them.
  List<PublicHoliday> upcoming() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [for (final h in _items) if (!h.date.isBefore(today) && !h.date.isAfter(today.add(const Duration(days: 365)))) h];
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<List<PublicHoliday>> list() async => [..._items]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<PublicHoliday> create({required DateTime date, required String nameAr, required String nameEn}) async {
    final problems = {
      if (nameAr.trim().isEmpty) 'nameAr': 'REQUIRED' else if (nameAr.trim().length > 100) 'nameAr': 'TOO_LONG',
      if (nameEn.trim().isEmpty) 'nameEn': 'REQUIRED' else if (nameEn.trim().length > 100) 'nameEn': 'TOO_LONG',
    };
    if (problems.isNotEmpty) {
      throw ApiException(kind: ApiErrorKind.http, status: 400, code: ApiCodes.validationFailed, fieldCodes: problems);
    }
    if (_items.any((h) => _sameDay(h.date, date))) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: publicHolidayExists);
    }
    final holiday = PublicHoliday(id: 'holiday-${_next++}', date: DateTime(date.year, date.month, date.day), nameAr: nameAr.trim(), nameEn: nameEn.trim());
    _items.add(holiday);
    return holiday;
  }

  @override
  Future<void> delete(String id) async {
    if (!_items.any((h) => h.id == id)) throw const ApiException(kind: ApiErrorKind.http, status: 404, code: ApiCodes.notFound);
    _items.removeWhere((h) => h.id == id);
  }
}
