import '../../billing/domain/billing_models.dart' show InvoiceStatus;
import '../../sessions/domain/session_models.dart'
    show SessionType, dayKey, parseDay;

export '../../sessions/domain/session_models.dart'
    show SessionType, dayKey, monthKey, parseDay, parseMonth;

/// Models of the doctor's analytics (D1, AS18) and revenue (D35) pages
/// (spec 6.14). The contract is backend/docs/api-phase-7.md; the API's
/// `Analytics/DashboardService.cs` and `RevenueService.cs` are the source of
/// truth. Money is in piasters. A part the caller may not see arrives as
/// `null` ("hidden", never zero), and the screens hide it (BR-REV1).

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
Map<String, dynamic> _map(Object? value) =>
    (value as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _list(Object? value) => [
  for (final row in value! as List) _map(row),
];
List<Map<String, dynamic>>? _listOrNull(Object? value) =>
    value == null ? null : _list(value);
String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
double _double(Object? value) => (value! as num).toDouble();
int _int(Object? value) => (value! as num).toInt();
int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

/// The period presets of BR-REV3. Weeks start on Saturday.
enum PeriodPreset {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last3Months,
  last6Months,
  thisYear,
  lastYear,
  custom;

  static PeriodPreset fromWire(Object? value) {
    for (final preset in values) {
      if (preset.name == value) return preset;
    }
    return thisMonth;
  }

  String get wire => name;
}

/// The filter bar of D1 (BR-REV2): period, branch, visit type, compare.
class AnalyticsFilter {
  const AnalyticsFilter({
    this.preset = PeriodPreset.thisMonth,
    this.from,
    this.to,
    this.branchId,
    this.type,
    this.compare = true,
  });

  final PeriodPreset preset;

  /// With [PeriodPreset.custom].
  final DateTime? from;
  final DateTime? to;
  final String? branchId;
  final SessionType? type;
  final bool compare;

  AnalyticsFilter copyWith({
    PeriodPreset? preset,
    DateTime? from,
    DateTime? to,
    Object? branchId = _keep,
    Object? type = _keep,
    bool? compare,
  }) => AnalyticsFilter(
    preset: preset ?? this.preset,
    from: from ?? this.from,
    to: to ?? this.to,
    branchId: identical(branchId, _keep) ? this.branchId : branchId as String?,
    type: identical(type, _keep) ? this.type : type as SessionType?,
    compare: compare ?? this.compare,
  );

  static const _keep = Object();

  /// The query of `GET /api/dashboard` and the D35 range.
  Map<String, Object> toQuery() => {
    'preset': preset.wire,
    if (preset == PeriodPreset.custom && from != null && to != null) ...{
      'from': dayKey(from!),
      'to': dayKey(to!),
    },
    'branchId': ?branchId,
    if (type != null) 'type': type!.wire,
    'compare': compare,
  };

  @override
  bool operator ==(Object other) =>
      other is AnalyticsFilter &&
      other.preset == preset &&
      other.from == from &&
      other.to == to &&
      other.branchId == branchId &&
      other.type == type &&
      other.compare == compare;

  @override
  int get hashCode => Object.hash(preset, from, to, branchId, type, compare);
}

/// A KPI tile: the value, the previous period's value and the change in percent.
class Tile {
  const Tile({required this.value, this.previous, this.changePct});

  factory Tile.fromJson(Map<String, dynamic> json) => Tile(
    value: _double(json['value']),
    previous: (json['previous'] as num?)?.toDouble(),
    changePct: (json['changePct'] as num?)?.toDouble(),
  );

  static Tile? maybe(Object? json) =>
      json == null ? null : Tile.fromJson(_map(json));

  final double value;
  final double? previous;
  final double? changePct;
}

class PeriodInfo {
  const PeriodInfo({
    required this.from,
    required this.to,
    required this.previousFrom,
    required this.previousTo,
    required this.preset,
    required this.bucket,
    required this.compare,
  });

  factory PeriodInfo.fromJson(Map<String, dynamic> json) => PeriodInfo(
    from: parseDay(json['from']),
    to: parseDay(json['to']),
    previousFrom: parseDay(json['previousFrom']),
    previousTo: parseDay(json['previousTo']),
    preset: PeriodPreset.fromWire(json['preset']),
    bucket: json['bucket'] as String,
    compare: json['compare'] as bool,
  );

  final DateTime from;
  final DateTime to;
  final DateTime previousFrom;
  final DateTime previousTo;
  final PeriodPreset preset;

  /// `day`, `week` or `month`: the chart granularity.
  final String bucket;
  final bool compare;
}

/// What the caller may see: revenue (`revenueView`), patient counts and
/// booking charts (`appointmentsView`) and the fee cards (`billingView`).
class DashboardAccess {
  const DashboardAccess({
    required this.revenue,
    required this.patients,
    required this.billing,
  });

  factory DashboardAccess.fromJson(Map<String, dynamic> json) =>
      DashboardAccess(
        revenue: json['revenue'] as bool,
        patients: json['patients'] as bool,
        billing: json['billing'] as bool,
      );

  final bool revenue;
  final bool patients;
  final bool billing;
}

class DashboardTiles {
  const DashboardTiles({
    this.revenue,
    this.netIncome,
    this.platformFees,
    this.visits,
    this.examinations,
    this.consultations,
    this.uniquePatients,
    this.newPatients,
    this.weeklyAveragePatients,
    this.averageRevenuePerVisit,
    this.noShowRate,
    this.appShare,
    this.averageWaitMinutes,
  });

  factory DashboardTiles.fromJson(Map<String, dynamic> json) => DashboardTiles(
    revenue: Tile.maybe(json['revenue']),
    netIncome: Tile.maybe(json['netIncome']),
    platformFees: Tile.maybe(json['platformFees']),
    visits: Tile.maybe(json['visits']),
    examinations: Tile.maybe(json['examinations']),
    consultations: Tile.maybe(json['consultations']),
    uniquePatients: Tile.maybe(json['uniquePatients']),
    newPatients: Tile.maybe(json['newPatients']),
    weeklyAveragePatients: Tile.maybe(json['weeklyAveragePatients']),
    averageRevenuePerVisit: Tile.maybe(json['averageRevenuePerVisit']),
    noShowRate: Tile.maybe(json['noShowRate']),
    appShare: Tile.maybe(json['appShare']),
    averageWaitMinutes: Tile.maybe(json['averageWaitMinutes']),
  );

  final Tile? revenue;
  final Tile? netIncome;
  final Tile? platformFees;
  final Tile? visits;
  final Tile? examinations;
  final Tile? consultations;
  final Tile? uniquePatients;
  final Tile? newPatients;
  final Tile? weeklyAveragePatients;
  final Tile? averageRevenuePerVisit;

  /// Percent (0–100).
  final Tile? noShowRate;

  /// Percent (0–100).
  final Tile? appShare;
  final Tile? averageWaitMinutes;
}

/// C1.
class RevenuePoint {
  const RevenuePoint({
    required this.date,
    required this.examinationPiasters,
    required this.consultationPiasters,
    this.previousTotalPiasters,
  });

  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
    date: parseDay(json['date']),
    examinationPiasters: _int(json['examinationPiasters']),
    consultationPiasters: _int(json['consultationPiasters']),
    previousTotalPiasters: _intOrNull(json['previousTotalPiasters']),
  );

  final DateTime date;
  final int examinationPiasters;
  final int consultationPiasters;
  final int? previousTotalPiasters;

  int get total => examinationPiasters + consultationPiasters;
}

/// C2.
class VisitsPoint {
  const VisitsPoint({
    required this.date,
    required this.examinations,
    required this.consultations,
    this.previousTotal,
  });

  factory VisitsPoint.fromJson(Map<String, dynamic> json) => VisitsPoint(
    date: parseDay(json['date']),
    examinations: _int(json['examinations']),
    consultations: _int(json['consultations']),
    previousTotal: _intOrNull(json['previousTotal']),
  );

  final DateTime date;
  final int examinations;
  final int consultations;
  final int? previousTotal;

  int get total => examinations + consultations;
}

/// C3.
class WeeklyPatients {
  const WeeklyPatients({required this.weeks, required this.average});

  factory WeeklyPatients.fromJson(Map<String, dynamic> json) => WeeklyPatients(
    weeks: [
      for (final row in _list(json['weeks']))
        (
          weekStart: parseDay(row['weekStart']),
          patients: _int(row['patients']),
        ),
    ],
    average: _double(json['average']),
  );

  final List<({DateTime weekStart, int patients})> weeks;
  final double average;
}

/// C4.
class MonthPoint {
  const MonthPoint({
    required this.monthKey,
    required this.visits,
    required this.lastYearVisits,
    required this.busiest,
    required this.quietest,
  });

  factory MonthPoint.fromJson(Map<String, dynamic> json) => MonthPoint(
    monthKey: json['monthKey'] as String,
    visits: _int(json['visits']),
    lastYearVisits: _int(json['lastYearVisits']),
    busiest: json['busiest'] as bool,
    quietest: json['quietest'] as bool,
  );

  final String monthKey;
  final int visits;
  final int lastYearVisits;
  final bool busiest;
  final bool quietest;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// C6.
class NewReturningPoint {
  const NewReturningPoint({
    required this.monthKey,
    required this.newPatients,
    required this.returning,
  });

  factory NewReturningPoint.fromJson(Map<String, dynamic> json) =>
      NewReturningPoint(
        monthKey: json['monthKey'] as String,
        newPatients: _int(json['new']),
        returning: _int(json['returning']),
      );

  final String monthKey;
  final int newPatients;
  final int returning;
}

/// C7.
class TypeSplit {
  const TypeSplit({
    required this.examinations,
    required this.consultations,
    this.examinationRevenue,
    this.consultationRevenue,
  });

  factory TypeSplit.fromJson(Map<String, dynamic> json) => TypeSplit(
    examinations: _int(json['examinations']),
    consultations: _int(json['consultations']),
    examinationRevenue: _intOrNull(json['examinationRevenuePiasters']),
    consultationRevenue: _intOrNull(json['consultationRevenuePiasters']),
  );

  final int examinations;
  final int consultations;
  final int? examinationRevenue;
  final int? consultationRevenue;
}

/// C8.
class BranchPoint {
  const BranchPoint({
    required this.branchId,
    required this.nameAr,
    this.nameEn,
    required this.visits,
    this.revenuePiasters,
  });

  factory BranchPoint.fromJson(Map<String, dynamic> json) => BranchPoint(
    branchId: json['branchId'] as String,
    nameAr: json['nameAr'] as String,
    nameEn: _text(json['nameEn']),
    visits: _int(json['visits']),
    revenuePiasters: _intOrNull(json['revenuePiasters']),
  );

  final String branchId;
  final String nameAr;
  final String? nameEn;
  final int visits;
  final int? revenuePiasters;

  String name(String languageCode) =>
      languageCode == 'en' && nameEn != null ? nameEn! : nameAr;
}

/// C9.
class Funnel {
  const Funnel({
    required this.booked,
    required this.arrived,
    required this.seen,
    required this.noShows,
    required this.cancellations,
    required this.weeks,
  });

  factory Funnel.fromJson(Map<String, dynamic> json) => Funnel(
    booked: _int(json['booked']),
    arrived: _int(json['arrived']),
    seen: _int(json['seen']),
    noShows: _int(json['noShows']),
    cancellations: _int(json['cancellations']),
    weeks: [
      for (final row in _list(json['weeks']))
        (
          weekStart: parseDay(row['weekStart']),
          noShows: _int(row['noShows']),
          cancellations: _int(row['cancellations']),
        ),
    ],
  );

  final int booked;
  final int arrived;
  final int seen;
  final int noShows;
  final int cancellations;
  final List<({DateTime weekStart, int noShows, int cancellations})> weeks;
}

/// C10.
class SourcePoint {
  const SourcePoint({
    required this.monthKey,
    required this.app,
    required this.staff,
    required this.walkIn,
  });

  factory SourcePoint.fromJson(Map<String, dynamic> json) => SourcePoint(
    monthKey: json['monthKey'] as String,
    app: _int(json['app']),
    staff: _int(json['staff']),
    walkIn: _int(json['walkIn']),
  );

  final String monthKey;
  final int app;
  final int staff;
  final int walkIn;
}

/// C11: patients whose last visit was more than [months] months ago; [filter]
/// is the D4 `lastVisit` filter that lists them (AC-24).
class NotSeenBucket {
  const NotSeenBucket({
    required this.months,
    required this.patients,
    required this.filter,
  });

  factory NotSeenBucket.fromJson(Map<String, dynamic> json) => NotSeenBucket(
    months: _int(json['months']),
    patients: _int(json['patients']),
    filter: json['filter'] as String,
  );

  final int months;
  final int patients;
  final String filter;
}

/// C12 [S].
class WaitPoint {
  const WaitPoint({required this.date, required this.minutes});

  factory WaitPoint.fromJson(Map<String, dynamic> json) => WaitPoint(
    date: parseDay(json['date']),
    minutes: _double(json['minutes']),
  );

  final DateTime date;
  final double minutes;
}

/// An automatic sentence (spec 6.14 "Insights"), in both languages.
class Insight {
  const Insight({
    required this.code,
    required this.textAr,
    required this.textEn,
    required this.screen,
    this.filter,
  });

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
    code: json['code'] as String,
    textAr: json['textAr'] as String,
    textEn: json['textEn'] as String,
    screen: json['screen'] as String,
    filter: _text(json['filter']),
  );

  final String code;
  final String textAr;
  final String textEn;

  /// `revenue`, `patients` or `dashboard`: where tapping it goes.
  final String screen;
  final String? filter;

  String text(String languageCode) => languageCode == 'en' ? textEn : textAr;
}

/// The invoice card of D1.
class InvoiceCard {
  const InvoiceCard({
    required this.id,
    required this.monthKey,
    required this.totalDuePiasters,
    required this.dueDate,
    required this.status,
    required this.daysLeft,
  });

  factory InvoiceCard.fromJson(Map<String, dynamic> json) => InvoiceCard(
    id: json['id'] as String,
    monthKey: json['monthKey'] as String,
    totalDuePiasters: _int(json['totalDuePiasters']),
    dueDate: parseDay(json['dueDate']),
    status: InvoiceStatus.fromWire(json['status']),
    daysLeft: _int(json['daysLeft']),
  );

  final String id;
  final String monthKey;
  final int totalDuePiasters;
  final DateTime dueDate;
  final InvoiceStatus status;
  final int daysLeft;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// The whole of `GET /api/dashboard`.
class Dashboard {
  const Dashboard({
    required this.period,
    required this.access,
    required this.tiles,
    this.revenueSeries,
    this.visitsSeries,
    this.patientsPerWeek,
    this.months,
    this.heatmap,
    this.newVsReturning,
    this.typeSplit,
    this.branches,
    this.funnel,
    this.sources,
    this.notSeen,
    this.waitingTimes,
    required this.insights,
    this.invoice,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
    period: PeriodInfo.fromJson(_map(json['period'])),
    access: DashboardAccess.fromJson(_map(json['access'])),
    tiles: DashboardTiles.fromJson(_map(json['tiles'])),
    revenueSeries: _listOrNull(
      json['revenueSeries'],
    )?.map(RevenuePoint.fromJson).toList(),
    visitsSeries: _listOrNull(
      json['visitsSeries'],
    )?.map(VisitsPoint.fromJson).toList(),
    patientsPerWeek: json['patientsPerWeek'] == null
        ? null
        : WeeklyPatients.fromJson(_map(json['patientsPerWeek'])),
    months: _listOrNull(json['months'])?.map(MonthPoint.fromJson).toList(),
    heatmap: json['heatmap'] == null
        ? null
        : [
            for (final row in json['heatmap'] as List)
              [for (final cell in row as List) _int(cell)],
          ],
    newVsReturning: _listOrNull(
      json['newVsReturning'],
    )?.map(NewReturningPoint.fromJson).toList(),
    typeSplit: json['typeSplit'] == null
        ? null
        : TypeSplit.fromJson(_map(json['typeSplit'])),
    branches: _listOrNull(json['branches'])?.map(BranchPoint.fromJson).toList(),
    funnel: json['funnel'] == null
        ? null
        : Funnel.fromJson(_map(json['funnel'])),
    sources: _listOrNull(json['sources'])?.map(SourcePoint.fromJson).toList(),
    notSeen: _listOrNull(json['notSeen'])?.map(NotSeenBucket.fromJson).toList(),
    waitingTimes: _listOrNull(
      json['waitingTimes'],
    )?.map(WaitPoint.fromJson).toList(),
    insights: _list(json['insights']).map(Insight.fromJson).toList(),
    invoice: json['invoice'] == null
        ? null
        : InvoiceCard.fromJson(_map(json['invoice'])),
  );

  final PeriodInfo period;
  final DashboardAccess access;
  final DashboardTiles tiles;
  final List<RevenuePoint>? revenueSeries;
  final List<VisitsPoint>? visitsSeries;
  final WeeklyPatients? patientsPerWeek;
  final List<MonthPoint>? months;

  /// 7 rows (Saturday first) of 24 hours.
  final List<List<int>>? heatmap;
  final List<NewReturningPoint>? newVsReturning;
  final TypeSplit? typeSplit;

  /// Only with two or more branches.
  final List<BranchPoint>? branches;
  final Funnel? funnel;
  final List<SourcePoint>? sources;
  final List<NotSeenBucket>? notSeen;
  final List<WaitPoint>? waitingTimes;
  final List<Insight> insights;
  final InvoiceCard? invoice;
}

// ---- D35 -------------------------------------------------------------------------------------

/// One line of the revenue tables.
class RevenueRow {
  const RevenueRow({
    required this.examinations,
    required this.examinationRevenue,
    required this.consultations,
    required this.consultationRevenue,
    required this.revenue,
    required this.platformFees,
    required this.net,
    required this.uniquePatients,
    required this.newPatients,
    required this.freeVisits,
    required this.discountedVisits,
    required this.discount,
  });

  factory RevenueRow.fromJson(Map<String, dynamic> json) => RevenueRow(
    examinations: _int(json['examinations']),
    examinationRevenue: _int(json['examinationRevenuePiasters']),
    consultations: _int(json['consultations']),
    consultationRevenue: _int(json['consultationRevenuePiasters']),
    revenue: _int(json['revenuePiasters']),
    platformFees: _int(json['platformFeesPiasters']),
    net: _int(json['netPiasters']),
    uniquePatients: _int(json['uniquePatients']),
    newPatients: _int(json['newPatients']),
    freeVisits: _int(json['freeVisits']),
    discountedVisits: _int(json['discountedVisits']),
    discount: _int(json['discountPiasters']),
  );

  final int examinations;
  final int examinationRevenue;
  final int consultations;
  final int consultationRevenue;
  final int revenue;
  final int platformFees;
  final int net;
  final int uniquePatients;
  final int newPatients;
  final int freeVisits;
  final int discountedVisits;
  final int discount;

  int get visits => examinations + consultations;
}

class RevenueMonthRow {
  const RevenueMonthRow({
    required this.monthKey,
    required this.row,
    this.changePct,
    this.invoiceId,
    this.invoiceStatus,
  });

  factory RevenueMonthRow.fromJson(Map<String, dynamic> json) =>
      RevenueMonthRow(
        monthKey: json['monthKey'] as String,
        row: RevenueRow.fromJson(_map(json['row'])),
        changePct: (json['changePct'] as num?)?.toDouble(),
        invoiceId: _text(json['invoiceId']),
        invoiceStatus: json['invoiceStatus'] == null
            ? null
            : InvoiceStatus.fromWire(json['invoiceStatus']),
      );

  final String monthKey;
  final RevenueRow row;
  final double? changePct;

  /// Only with `billingView`.
  final String? invoiceId;
  final InvoiceStatus? invoiceStatus;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class RevenueBranchRow {
  const RevenueBranchRow({
    required this.branchId,
    required this.nameAr,
    this.nameEn,
    required this.row,
  });

  factory RevenueBranchRow.fromJson(Map<String, dynamic> json) =>
      RevenueBranchRow(
        branchId: json['branchId'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: _text(json['nameEn']),
        row: RevenueRow.fromJson(_map(json['row'])),
      );

  final String branchId;
  final String nameAr;
  final String? nameEn;
  final RevenueRow row;

  String name(String languageCode) =>
      languageCode == 'en' && nameEn != null ? nameEn! : nameAr;
}

class RevenueReport {
  const RevenueReport({
    required this.from,
    required this.to,
    required this.months,
    required this.totals,
    this.bestMonth,
    this.worstMonth,
    required this.byBranch,
    required this.byType,
    required this.byPaymentMethod,
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) => RevenueReport(
    from: parseDay(json['from']),
    to: parseDay(json['to']),
    months: _list(json['months']).map(RevenueMonthRow.fromJson).toList(),
    totals: RevenueRow.fromJson(_map(json['totals'])),
    bestMonth: _text(json['bestMonth']),
    worstMonth: _text(json['worstMonth']),
    byBranch: _list(json['byBranch']).map(RevenueBranchRow.fromJson).toList(),
    byType: [
      for (final row in _list(json['byType']))
        (
          type: SessionType.fromWire(row['type']),
          row: RevenueRow.fromJson(_map(row['row'])),
        ),
    ],
    byPaymentMethod: [
      for (final row in _list(json['byPaymentMethod']))
        (
          method: _text(row['method']),
          row: RevenueRow.fromJson(_map(row['row'])),
        ),
    ],
  );

  final DateTime from;
  final DateTime to;
  final List<RevenueMonthRow> months;
  final RevenueRow totals;
  final String? bestMonth;
  final String? worstMonth;
  final List<RevenueBranchRow> byBranch;
  final List<({SessionType type, RevenueRow row})> byType;
  final List<({String? method, RevenueRow row})> byPaymentMethod;
}

class RevenueMonth {
  const RevenueMonth({
    required this.monthKey,
    required this.days,
    required this.totals,
  });

  factory RevenueMonth.fromJson(Map<String, dynamic> json) => RevenueMonth(
    monthKey: json['monthKey'] as String,
    days: [
      for (final row in _list(json['days']))
        (day: parseDay(row['day']), row: RevenueRow.fromJson(_map(row['row']))),
    ],
    totals: RevenueRow.fromJson(_map(json['totals'])),
  );

  final String monthKey;
  final List<({DateTime day, RevenueRow row})> days;
  final RevenueRow totals;
}

/// A session of a day, as D35's last level shows it.
class RevenueSession {
  const RevenueSession({
    required this.id,
    required this.at,
    required this.patientId,
    required this.patientName,
    required this.branchId,
    required this.branchNameAr,
    this.branchNameEn,
    required this.type,
    this.listPricePiasters,
    required this.amountChargedPiasters,
    required this.discountPiasters,
    this.paymentMethod,
    required this.recordedBy,
    required this.recordedByRole,
  });

  factory RevenueSession.fromJson(Map<String, dynamic> json) => RevenueSession(
    id: json['id'] as String,
    at: _time(json['at']),
    patientId: json['patientId'] as String,
    patientName: json['patientName'] as String,
    branchId: json['branchId'] as String,
    branchNameAr: json['branchNameAr'] as String,
    branchNameEn: _text(json['branchNameEn']),
    type: SessionType.fromWire(json['type']),
    listPricePiasters: _intOrNull(json['listPricePiasters']),
    amountChargedPiasters: _int(json['amountChargedPiasters']),
    discountPiasters: _int(json['discountPiasters']),
    paymentMethod: _text(json['paymentMethod']),
    recordedBy: json['recordedBy'] as String,
    recordedByRole: json['recordedByRole'] as String,
  );

  final String id;
  final DateTime at;
  final String patientId;
  final String patientName;
  final String branchId;
  final String branchNameAr;
  final String? branchNameEn;
  final SessionType type;
  final int? listPricePiasters;
  final int amountChargedPiasters;
  final int discountPiasters;
  final String? paymentMethod;
  final String recordedBy;
  final String recordedByRole;

  String branchName(String languageCode) =>
      languageCode == 'en' && branchNameEn != null
      ? branchNameEn!
      : branchNameAr;
}

class RevenueDay {
  const RevenueDay({
    required this.day,
    required this.sessions,
    required this.totals,
  });

  factory RevenueDay.fromJson(Map<String, dynamic> json) => RevenueDay(
    day: parseDay(json['day']),
    sessions: _list(json['sessions']).map(RevenueSession.fromJson).toList(),
    totals: RevenueRow.fromJson(_map(json['totals'])),
  );

  final DateTime day;
  final List<RevenueSession> sessions;
  final RevenueRow totals;
}

/// The D35 filter (year or range, branch, visit type).
class RevenueFilter {
  const RevenueFilter({required this.year, this.branchId, this.type});

  final int year;
  final String? branchId;
  final SessionType? type;

  RevenueFilter copyWith({
    int? year,
    Object? branchId = _keep,
    Object? type = _keep,
  }) => RevenueFilter(
    year: year ?? this.year,
    branchId: identical(branchId, _keep) ? this.branchId : branchId as String?,
    type: identical(type, _keep) ? this.type : type as SessionType?,
  );

  static const _keep = Object();

  Map<String, Object> toQuery() => {
    'year': year,
    'branchId': ?branchId,
    if (type != null) 'type': type!.wire,
  };

  @override
  bool operator ==(Object other) =>
      other is RevenueFilter &&
      other.year == year &&
      other.branchId == branchId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(year, branchId, type);
}
