import '../../billing/domain/billing_models.dart' show InvoiceStatus;
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';

/// Offline numbers for the dev accounts and the tests. Visits follow a simple
/// pattern per day, so every chart has something to draw and a change of
/// period, branch or visit type changes every number. [revenue], [patients]
/// and [billing] switch parts off like an assistant's permissions do (hidden,
/// never zero).
class FakeAnalyticsRepository implements AnalyticsRepository {
  FakeAnalyticsRepository({
    DateTime? today,
    bool revenue = true,
    this.patients = true,
    this.billing = true,
  }) : _today = today ?? _cairoToday(),
       _revenue = revenue;

  final DateTime _today;
  final bool _revenue;
  final bool patients;
  final bool billing;

  static DateTime _cairoToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    return DateTime.utc(now.year, now.month, now.day);
  }

  static const _examPrice = 30000;
  static const _consultationPrice = 15000;
  static const _examFee = 3000;
  static const _consultationFee = 1500;

  /// Visits on a day: (examinations, consultations). Fridays are quiet.
  (int, int) _visits(DateTime day, {String? branchId, SessionType? type}) {
    if (day.isAfter(_today)) return (0, 0);
    var exams = day.weekday == DateTime.friday ? 2 : 6 + day.day % 4;
    var consultations = day.weekday == DateTime.friday ? 1 : 2 + day.day % 3;
    if (branchId == 'branch-2') {
      exams = exams ~/ 3;
      consultations = consultations ~/ 3;
    } else if (branchId == 'branch-1') {
      exams -= exams ~/ 3;
      consultations -= consultations ~/ 3;
    }
    return (
      type == SessionType.consultation ? 0 : exams,
      type == SessionType.examination ? 0 : consultations,
    );
  }

  (DateTime, DateTime) _period(AnalyticsFilter filter) {
    final today = _today;
    final weekStart = today.subtract(Duration(days: (today.weekday + 1) % 7));
    final monthStart = DateTime.utc(today.year, today.month);
    return switch (filter.preset) {
      PeriodPreset.today => (today, today),
      PeriodPreset.yesterday => (
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 1)),
      ),
      PeriodPreset.thisWeek => (weekStart, today),
      PeriodPreset.lastWeek => (
        weekStart.subtract(const Duration(days: 7)),
        weekStart.subtract(const Duration(days: 1)),
      ),
      PeriodPreset.thisMonth => (monthStart, today),
      PeriodPreset.lastMonth => (
        DateTime.utc(today.year, today.month - 1),
        monthStart.subtract(const Duration(days: 1)),
      ),
      PeriodPreset.last3Months => (
        DateTime.utc(today.year, today.month - 3, today.day + 1),
        today,
      ),
      PeriodPreset.last6Months => (
        DateTime.utc(today.year, today.month - 6, today.day + 1),
        today,
      ),
      PeriodPreset.thisYear => (DateTime.utc(today.year), today),
      PeriodPreset.lastYear => (
        DateTime.utc(today.year - 1),
        DateTime.utc(today.year - 1, 12, 31),
      ),
      PeriodPreset.custom => (filter.from ?? monthStart, filter.to ?? today),
    };
  }

  _Sum _sum(DateTime from, DateTime to, {String? branchId, SessionType? type}) {
    var exams = 0;
    var consultations = 0;
    for (
      var day = from;
      !day.isAfter(to);
      day = day.add(const Duration(days: 1))
    ) {
      final (e, c) = _visits(day, branchId: branchId, type: type);
      exams += e;
      consultations += c;
    }
    return _Sum(exams, consultations);
  }

  Tile _tile(double value, double? previous) => Tile(
    value: value,
    previous: previous,
    changePct: previous == null || previous == 0
        ? null
        : (value - previous) / previous * 100,
  );

  @override
  Future<Dashboard> dashboard(AnalyticsFilter filter) async {
    final (from, to) = _period(filter);
    final days = to.difference(from).inDays + 1;
    final previousTo = from.subtract(const Duration(days: 1));
    final previousFrom = previousTo.subtract(Duration(days: days - 1));
    final now = _sum(from, to, branchId: filter.branchId, type: filter.type);
    final then = filter.compare
        ? _sum(
            previousFrom,
            previousTo,
            branchId: filter.branchId,
            type: filter.type,
          )
        : null;
    final bucket = days <= 31 ? 'day' : (days <= 190 ? 'week' : 'month');

    Tile? money(double Function(_Sum) pick) =>
        _revenue ? _tile(pick(now), then == null ? null : pick(then)) : null;
    Tile? count(double Function(_Sum) pick) =>
        patients ? _tile(pick(now), then == null ? null : pick(then)) : null;
    final weeks = (days / 7).clamp(1, 1000).toDouble();

    // Chart buckets.
    final starts = <DateTime>[];
    DateTime bucketOf(DateTime day) => switch (bucket) {
      'day' => day,
      'week' => day.subtract(Duration(days: (day.weekday + 1) % 7)),
      _ => DateTime.utc(day.year, day.month),
    };
    for (
      var day = from;
      !day.isAfter(to);
      day = day.add(const Duration(days: 1))
    ) {
      final start = bucketOf(day);
      if (starts.isEmpty || starts.last != start) starts.add(start);
    }
    _Sum inBucket(DateTime start, {int shift = 0}) {
      var total = _Sum(0, 0);
      for (
        var day = from;
        !day.isAfter(to);
        day = day.add(const Duration(days: 1))
      ) {
        if (bucketOf(day) != start) continue;
        final other = day.subtract(Duration(days: days * shift));
        final (e, c) = _visits(
          other,
          branchId: filter.branchId,
          type: filter.type,
        );
        total = _Sum(total.exams + e, total.consultations + c);
      }
      return total;
    }

    final points = [
      for (final start in starts)
        (
          start: start,
          now: inBucket(start),
          before: filter.compare ? inBucket(start, shift: 1) : null,
        ),
    ];

    final monthKeys = [
      for (var i = 11; i >= 0; i--) DateTime.utc(_today.year, _today.month - i),
    ];
    final monthVisits = [
      for (final month in monthKeys)
        _sum(
          month,
          DateTime.utc(month.year, month.month + 1, 0),
          branchId: filter.branchId,
          type: filter.type,
        ).visits,
    ];
    final ranked = [for (var i = 0; i < 12; i++) i]
      ..sort((a, b) => monthVisits[b].compareTo(monthVisits[a]));

    final heat = [
      for (var d = 0; d < 7; d++)
        [
          for (var h = 0; h < 24; h++)
            (h >= 9 && h <= 20) ? (d == 0 ? 6 : 3) + (h % 4) : 0,
        ],
    ];

    final branches = filter.branchId == null
        ? [
            BranchPoint(
              branchId: 'branch-1',
              nameAr: 'فرع المعادي',
              nameEn: 'Maadi branch',
              visits: (now.visits * 0.65).round(),
              revenuePiasters: _revenue ? (now.revenue * 0.65).round() : null,
            ),
            BranchPoint(
              branchId: 'branch-2',
              nameAr: 'فرع مدينة نصر',
              nameEn: 'Nasr City branch',
              visits: (now.visits * 0.35).round(),
              revenuePiasters: _revenue ? (now.revenue * 0.35).round() : null,
            ),
          ]
        : null;

    final lastMonthKey =
        '${_today.year}-${_today.month.toString().padLeft(2, '0')}';
    return Dashboard(
      period: PeriodInfo(
        from: from,
        to: to,
        previousFrom: previousFrom,
        previousTo: previousTo,
        preset: filter.preset,
        bucket: bucket,
        compare: filter.compare,
      ),
      access: DashboardAccess(
        revenue: _revenue,
        patients: patients,
        billing: billing,
      ),
      tiles: DashboardTiles(
        revenue: money((s) => s.revenue.toDouble()),
        netIncome: money((s) => (s.revenue - s.fees).toDouble()),
        platformFees: billing
            ? _tile(now.fees.toDouble(), then?.fees.toDouble())
            : null,
        visits: count((s) => s.visits.toDouble()),
        examinations: count((s) => s.exams.toDouble()),
        consultations: count((s) => s.consultations.toDouble()),
        uniquePatients: count((s) => (s.visits * 0.7).roundToDouble()),
        newPatients: count((s) => (s.visits * 0.12).roundToDouble()),
        weeklyAveragePatients: count((s) => s.visits * 0.7 / weeks),
        averageRevenuePerVisit: money(
          (s) => s.visits == 0 ? 0 : s.revenue / s.visits,
        ),
        noShowRate: patients ? _tile(11.5, then == null ? null : 9) : null,
        appShare: patients ? _tile(38, then == null ? null : 34) : null,
        averageWaitMinutes: patients
            ? _tile(22, then == null ? null : 25)
            : null,
      ),
      revenueSeries: _revenue
          ? [
              for (final p in points)
                RevenuePoint(
                  date: p.start,
                  examinationPiasters: p.now.exams * _examPrice,
                  consultationPiasters:
                      p.now.consultations * _consultationPrice,
                  previousTotalPiasters: p.before?.revenue,
                ),
            ]
          : null,
      visitsSeries: patients
          ? [
              for (final p in points)
                VisitsPoint(
                  date: p.start,
                  examinations: p.now.exams,
                  consultations: p.now.consultations,
                  previousTotal: p.before?.visits,
                ),
            ]
          : null,
      patientsPerWeek: patients
          ? WeeklyPatients(
              weeks: [
                for (final p in points.take(12))
                  (weekStart: p.start, patients: (p.now.visits * 0.7).round()),
              ],
              average: now.visits * 0.7 / weeks,
            )
          : null,
      months: patients
          ? [
              for (var i = 0; i < 12; i++)
                MonthPoint(
                  monthKey:
                      '${monthKeys[i].year}-${monthKeys[i].month.toString().padLeft(2, '0')}',
                  visits: monthVisits[i],
                  lastYearVisits: (monthVisits[i] * 0.85).round(),
                  busiest: ranked.take(3).contains(i),
                  quietest: ranked.reversed.take(3).contains(i),
                ),
            ]
          : null,
      heatmap: patients ? heat : null,
      newVsReturning: patients
          ? [
              for (final month in monthKeys.skip(9))
                NewReturningPoint(
                  monthKey:
                      '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  newPatients: 14,
                  returning: 96,
                ),
            ]
          : null,
      typeSplit: patients
          ? TypeSplit(
              examinations: now.exams,
              consultations: now.consultations,
              examinationRevenue: _revenue ? now.exams * _examPrice : null,
              consultationRevenue: _revenue
                  ? now.consultations * _consultationPrice
                  : null,
            )
          : null,
      branches: patients ? branches : null,
      funnel: patients
          ? Funnel(
              booked: now.visits + 8,
              arrived: now.visits + 2,
              seen: now.visits,
              noShows: 6,
              cancellations: 5,
              weeks: [
                for (final p in points.take(8))
                  (
                    weekStart: p.start,
                    noShows: 1 + p.start.day % 3,
                    cancellations: p.start.day % 2,
                  ),
              ],
            )
          : null,
      sources: patients
          ? [
              for (final month in monthKeys.skip(9))
                SourcePoint(
                  monthKey:
                      '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  app: 30,
                  staff: 55,
                  walkIn: 22,
                ),
            ]
          : null,
      notSeen: patients
          ? const [
              NotSeenBucket(months: 3, patients: 31, filter: 'notSeen3m'),
              NotSeenBucket(months: 6, patients: 18, filter: 'notSeen6m'),
              NotSeenBucket(months: 12, patients: 7, filter: 'notSeen12m'),
            ]
          : null,
      waitingTimes: patients
          ? [
              for (final p in points.take(14))
                WaitPoint(date: p.start, minutes: 15.0 + p.start.day % 12),
            ]
          : null,
      insights: [
        if (_revenue && then != null && then.revenue > 0)
          Insight(
            code: 'revenueChange',
            textAr: 'إيرادات هذه الفترة أعلى بنسبة 12% من الفترة السابقة',
            textEn:
                'Revenue this period is 12% higher than the previous period',
            screen: 'revenue',
          ),
        if (patients) ...const [
          Insight(
            code: 'busiestTime',
            textAr: 'أكثر الأوقات زحاماً: السبت مساءً',
            textEn: 'Busiest time: Saturday in the evening',
            screen: 'dashboard',
          ),
          Insight(
            code: 'notSeen6Months',
            textAr: '18 مريضاً لم يزوروك منذ 6 أشهر',
            textEn: '18 patients haven\'t visited in 6 months',
            screen: 'patients',
            filter: 'notSeen6m',
          ),
        ],
      ],
      invoice: billing
          ? InvoiceCard(
              id: 'inv-1',
              monthKey: lastMonthKey,
              totalDuePiasters: 78000,
              dueDate: _today.add(const Duration(days: 2)),
              status: InvoiceStatus.unpaid,
              daysLeft: 2,
            )
          : null,
    );
  }

  @override
  Future<RevenueReport> revenue(RevenueFilter filter) async {
    final last = filter.year == _today.year ? _today.month : 12;
    final rows = <RevenueMonthRow>[];
    int? previous;
    for (var month = 1; month <= last; month++) {
      final first = DateTime.utc(filter.year, month);
      final row = _row(
        first,
        DateTime.utc(filter.year, month + 1, 0),
        filter.branchId,
        filter.type,
      );
      rows.add(
        RevenueMonthRow(
          monthKey: '${filter.year}-${month.toString().padLeft(2, '0')}',
          row: row,
          changePct: previous == null || previous == 0
              ? null
              : (row.revenue - previous) / previous * 100,
          invoiceId: billing && month < _today.month
              ? 'inv-${filter.year}-$month'
              : null,
        ),
      );
      previous = row.revenue;
    }
    final total = _row(
      DateTime.utc(filter.year),
      DateTime.utc(filter.year, last + 1, 0),
      filter.branchId,
      filter.type,
    );
    final ranked = [...rows]
      ..sort((a, b) => b.row.revenue.compareTo(a.row.revenue));
    return RevenueReport(
      from: DateTime.utc(filter.year),
      to: DateTime.utc(filter.year, last + 1, 0),
      months: rows,
      totals: total,
      bestMonth: rows.length >= 2 ? ranked.first.monthKey : null,
      worstMonth: rows.length >= 2 ? ranked.last.monthKey : null,
      byBranch: [
        RevenueBranchRow(
          branchId: 'branch-1',
          nameAr: 'فرع المعادي',
          nameEn: 'Maadi branch',
          row: _row(
            DateTime.utc(filter.year),
            DateTime.utc(filter.year, last + 1, 0),
            'branch-1',
            filter.type,
          ),
        ),
        RevenueBranchRow(
          branchId: 'branch-2',
          nameAr: 'فرع مدينة نصر',
          nameEn: 'Nasr City branch',
          row: _row(
            DateTime.utc(filter.year),
            DateTime.utc(filter.year, last + 1, 0),
            'branch-2',
            filter.type,
          ),
        ),
      ],
      byType: [
        (
          type: SessionType.examination,
          row: _row(
            DateTime.utc(filter.year),
            DateTime.utc(filter.year, last + 1, 0),
            filter.branchId,
            SessionType.examination,
          ),
        ),
        (
          type: SessionType.consultation,
          row: _row(
            DateTime.utc(filter.year),
            DateTime.utc(filter.year, last + 1, 0),
            filter.branchId,
            SessionType.consultation,
          ),
        ),
      ],
      byPaymentMethod: [(method: 'cash', row: total)],
    );
  }

  RevenueRow _row(
    DateTime from,
    DateTime to,
    String? branchId,
    SessionType? type,
  ) {
    final sum = _sum(from, to, branchId: branchId, type: type);
    final discounted = sum.visits ~/ 10;
    return RevenueRow(
      examinations: sum.exams,
      examinationRevenue: sum.exams * _examPrice,
      consultations: sum.consultations,
      consultationRevenue: sum.consultations * _consultationPrice,
      revenue: sum.revenue,
      platformFees: sum.fees,
      net: sum.revenue - sum.fees,
      uniquePatients: (sum.visits * 0.7).round(),
      newPatients: (sum.visits * 0.12).round(),
      freeVisits: sum.visits ~/ 25,
      discountedVisits: discounted,
      discount: discounted * 5000,
    );
  }

  @override
  Future<RevenueMonth> revenueMonth(
    String month, {
    String? branchId,
    SessionType? type,
  }) async {
    final parts = month.split('-');
    final first = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
    final last = DateTime.utc(first.year, first.month + 1, 0);
    final end = last.isAfter(_today) ? _today : last;
    return RevenueMonth(
      monthKey: month,
      days: [
        for (
          var day = first;
          !day.isAfter(end);
          day = day.add(const Duration(days: 1))
        )
          (day: day, row: _row(day, day, branchId, type)),
      ],
      totals: _row(first, end, branchId, type),
    );
  }

  @override
  Future<RevenueDay> revenueDay(
    DateTime day, {
    String? branchId,
    SessionType? type,
  }) async {
    final (exams, consultations) = _visits(day, branchId: branchId, type: type);
    final sessions = <RevenueSession>[
      for (var i = 0; i < exams + consultations; i++)
        RevenueSession(
          id: 's-$i',
          at: day.add(Duration(hours: 8 + i)),
          patientId: 'p-$i',
          patientName: 'مريض ${i + 1}',
          branchId: 'branch-1',
          branchNameAr: 'فرع المعادي',
          branchNameEn: 'Maadi branch',
          type: i < exams ? SessionType.examination : SessionType.consultation,
          listPricePiasters: i < exams ? _examPrice : _consultationPrice,
          amountChargedPiasters: i == 1
              ? 25000
              : (i < exams ? _examPrice : _consultationPrice),
          discountPiasters: i == 1 ? 5000 : 0,
          paymentMethod: 'cash',
          recordedBy: i.isEven ? 'د. تجريبي' : 'منى (الاستقبال)',
          recordedByRole: i.isEven ? 'doctor' : 'assistant',
        ),
    ];
    return RevenueDay(
      day: day,
      sessions: sessions,
      totals: _row(day, day, branchId, type),
    );
  }
}

class _Sum {
  const _Sum(this.exams, this.consultations);

  final int exams;
  final int consultations;

  int get visits => exams + consultations;
  int get revenue =>
      exams * FakeAnalyticsRepository._examPrice +
      consultations * FakeAnalyticsRepository._consultationPrice;
  int get fees =>
      exams * FakeAnalyticsRepository._examFee +
      consultations * FakeAnalyticsRepository._consultationFee;
}
