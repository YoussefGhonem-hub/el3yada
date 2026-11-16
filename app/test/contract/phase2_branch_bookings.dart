import 'dart:io';

import 'package:el3yada/features/clinic_admin/data/clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/domain/branch_models.dart';
import 'package:el3yada/features/clinic_admin/domain/json_read.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_support.dart';

/// Phase 2 against a running API: a branch with a booking (D28, BR-BR9).
/// Bookings get their endpoints in Phase 6, so the backend's
/// Development-only `add-booking` command puts one in the database: tomorrow,
/// in the clinic day's second branch, for its first patient. The command runs
/// with `dotnet run --no-build` in `EL3YADA_BACKEND_DIR` (default
/// `../backend`) and this process's environment, so `ConnectionStrings__Default`
/// must name the contract test's database, the one the API uses.
///
/// Called by `api_contract_test.dart` after [ClinicDay] is filled in.
void phase2BranchBookings(ClinicDay day, {required String? skip}) {
  test('a booking counts on the branch card and stops closing and archiving the branch', () async {
    final env = Platform.environment;
    expect(env['ConnectionStrings__Default'], isNotNull,
        reason: 'add-booking writes to ConnectionStrings__Default: set it to the contract database');
    final backend = env['EL3YADA_BACKEND_DIR'] ?? '../backend';
    final result = await Process.run(
      'dotnet',
      ['run', '--no-build', '--project', 'src/El3yada.Api', '--', 'add-booking', '--branch', day.dokkiId, '--patient', day.patientId],
      workingDirectory: backend,
    );
    final output = '${result.stdout}${result.stderr}';
    expect(result.exitCode, 0, reason: output);
    final bookingId = RegExp(r'Added booking ([0-9a-f-]{36})').firstMatch(output)?.group(1);
    expect(bookingId, isNotNull, reason: output);
    final tomorrow = dayKey(parseDay(day.today).add(const Duration(days: 1)));

    final branches = day.doctor.clinicAdmin;
    var cards = (await branches.branches()).items;
    expect(cards.singleWhere((b) => b.id == day.dokkiId).upcomingBookings, 1);
    expect(cards.singleWhere((b) => b.id == day.maadiId).upcomingBookings, 0);
    final patientName = (await day.doctor.patients.patient(day.patientId)).fullName;

    // Archiving, closing with no reopening date, and closing until after the
    // booking are refused, with the booking.
    final afterIt = parseDay(day.today).add(const Duration(days: 2));
    for (final attempt in [
      () => branches.setBranchStatus(day.dokkiId, BranchStatuses.archived),
      () => branches.setBranchStatus(day.dokkiId, BranchStatuses.temporarilyClosed, closedMessage: 'مغلق للتجديدات'),
      () => branches.setBranchStatus(day.dokkiId, BranchStatuses.temporarilyClosed,
          closedMessage: 'مغلق للتجديدات', reopenDate: DateTime(afterIt.year, afterIt.month, afterIt.day)),
    ]) {
      final refusal = await _bookingsRefusal(attempt());
      expect(refusal.status, 409);
      expect(refusal.code, ClinicAdminCodes.branchHasBookings);
      expect(refusal.totalCount, 1);
      final booking = refusal.bookings.single;
      expect(booking.id, bookingId);
      expect(writeDay(booking.localDate), tomorrow);
      expect(booking.periodStartLocal, '10:00');
      expect(booking.status, 'confirmed');
      expect(booking.visitType, 'examination');
      expect(booking.patientId, day.patientId);
      expect(booking.name, patientName);
      expect(booking.isGuest, isFalse);
      // The whole answer is there too.
      expect(refusal.details['code'], ClinicAdminCodes.branchHasBookings);
      expect(refusal.details['status'], 409);
      expect(refusal.details['totalCount'], 1);
      final sent = ((refusal.details['bookings']! as List).single as Map).cast<String, Object?>();
      expect(sent['id'], bookingId);
      final startUtc = DateTime.parse(sent['startUtc']! as String);
      expect(startUtc.isUtc, isTrue);
      expect(dayKey(startUtc), tomorrow);
      expect(startUtc.hour, anyOf(7, 8), reason: '10:00 in Cairo');
    }
    expect((await branches.branch(day.dokkiId)).status, BranchStatuses.active);

    // A closure that reopens on the booking's day doesn't touch it.
    final closed = await branches.setBranchStatus(day.dokkiId, BranchStatuses.temporarilyClosed,
        closedMessage: 'مغلق اليوم', reopenDate: readDay(tomorrow));
    expect(closed.status, BranchStatuses.temporarilyClosed);
    expect(writeDay(closed.reopenDate!), tomorrow);
    expect((await branches.setBranchStatus(day.dokkiId, BranchStatuses.active)).status, BranchStatuses.active);
    cards = (await branches.branches()).items;
    expect(cards.singleWhere((b) => b.id == day.dokkiId).upcomingBookings, 1);
  }, skip: skip);
}

Future<BranchHasBookingsException> _bookingsRefusal(Future<Object?> call) async {
  try {
    await call;
  } on BranchHasBookingsException catch (error) {
    return error;
  }
  fail('expected BRANCH_HAS_BOOKINGS');
}
