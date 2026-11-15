import '../../../core/data/paged.dart';
import '../../../core/format/app_format.dart';
import 'branch_models.dart';
import 'json_read.dart';

/// Visit prices (D37, AS19; section 6.15): the clinic's prices for its
/// patients, not the platform fees. Money is integer piasters.

/// An examination and a consultation price; null is "not set" for the
/// doctor and "use the doctor's" for a branch.
class PricePair {
  const PricePair({this.examinationPricePiasters, this.consultationPricePiasters});

  factory PricePair.fromJson(Map<String, dynamic>? json) => PricePair(
        examinationPricePiasters: json?['examinationPricePiasters'] as int?,
        consultationPricePiasters: json?['consultationPricePiasters'] as int?,
      );

  final int? examinationPricePiasters;
  final int? consultationPricePiasters;

  bool get isEmpty => examinationPricePiasters == null && consultationPricePiasters == null;

  @override
  bool operator ==(Object other) =>
      other is PricePair &&
      other.examinationPricePiasters == examinationPricePiasters &&
      other.consultationPricePiasters == consultationPricePiasters;

  @override
  int get hashCode => Object.hash(examinationPricePiasters, consultationPricePiasters);
}

/// One branch in D37.
class BranchPriceRow {
  const BranchPriceRow({
    required this.branchId,
    required this.nameAr,
    this.nameEn,
    required this.status,
    required this.isDefault,
    required this.assigned,
    required this.prices,
  });

  factory BranchPriceRow.fromJson(Map<String, dynamic> json) => BranchPriceRow(
        branchId: json['branchId'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: readText(json['nameEn']),
        status: json['status'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
        assigned: json['assigned'] as bool? ?? true,
        prices: VisitPrices.fromJson(readMap(json['prices'])),
      );

  final String branchId;
  final String nameAr;
  final String? nameEn;
  final String status;
  final bool isDefault;

  /// The caller may change this branch's prices (BR-AS13; always true for the doctor).
  final bool assigned;
  final VisitPrices prices;

  String name(String languageCode) => branchName(languageCode, nameAr, nameEn);
}

/// Who changed a price.
class PriceChangedBy {
  const PriceChangedBy({this.userId, this.name, required this.role});

  factory PriceChangedBy.fromJson(Map<String, dynamic> json) => PriceChangedBy(
        userId: json['userId'] as String?,
        name: readText(json['name']),
        role: json['role'] as String? ?? 'doctor',
      );

  final String? userId;
  final String? name;

  /// `doctor` or `assistant`.
  final String role;
}

/// One D37 history row (BR-PR5): date, who, branch, old → new.
class PriceHistoryEntry {
  const PriceHistoryEntry({
    required this.id,
    required this.changedAt,
    required this.changedBy,
    this.branchId,
    this.branchNameAr,
    this.branchNameEn,
    required this.before,
    required this.after,
  });

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final branch = readMapOrNull(json['branch']);
    return PriceHistoryEntry(
      id: json['id'] as String,
      changedAt: readTime(json['changedAt']),
      changedBy: PriceChangedBy.fromJson(readMap(json['changedBy'])),
      branchId: branch?['id'] as String?,
      branchNameAr: branch?['nameAr'] as String?,
      branchNameEn: readText(branch?['nameEn']),
      before: PricePair.fromJson(readMapOrNull(json['before'])),
      after: PricePair.fromJson(readMapOrNull(json['after'])),
    );
  }

  final String id;
  final DateTime changedAt;
  final PriceChangedBy changedBy;

  /// Null: the doctor's prices.
  final String? branchId;
  final String? branchNameAr;
  final String? branchNameEn;
  final PricePair before;
  final PricePair after;

  String? branchName(String languageCode) =>
      branchNameAr == null ? null : (languageCode == 'en' && branchNameEn != null ? branchNameEn : branchNameAr);
}

/// D37: `GET /api/prices` (and the answer of `updatePrices`).
class PricesOverview {
  const PricesOverview({required this.doctor, required this.branches, required this.history});

  factory PricesOverview.fromJson(Map<String, dynamic> json) => PricesOverview(
        doctor: PricePair.fromJson(readMapOrNull(json['doctor'])),
        branches: [for (final row in readList(json['branches'])) BranchPriceRow.fromJson(row)],
        history: Paged.fromJson(readMap(json['history']), PriceHistoryEntry.fromJson),
      );

  final PricePair doctor;
  final List<BranchPriceRow> branches;
  final Paged<PriceHistoryEntry> history;
}

/// Why a typed price isn't accepted.
enum PriceProblem { invalid }

/// Visit price input (spec section 11): optional, 0–100,000 EGP, at most 2
/// decimals. The API takes piasters.
abstract final class PriceRules {
  /// 100,000 EGP.
  static const maxPiasters = 10000000;

  /// Null for an empty field (not set / use the doctor's) or the piasters;
  /// throws [FormatException] for anything else.
  static int? toPiasters(String text) {
    if (text.trim().isEmpty) return null;
    final piasters = AppFormat.parseEgp(text);
    if (piasters == null || piasters > maxPiasters) throw FormatException('Not a visit price', text);
    return piasters;
  }

  /// The problem with [text], or null when it is empty or a valid price.
  static PriceProblem? check(String text) {
    try {
      toPiasters(text);
      return null;
    } on FormatException {
      return PriceProblem.invalid;
    }
  }

  /// What a price field shows for [piasters]: `300`, `150.50`, or '' for none.
  static String toInput(int? piasters) {
    if (piasters == null) return '';
    final rest = piasters % 100;
    return rest == 0 ? '${piasters ~/ 100}' : '${piasters ~/ 100}.${rest.toString().padLeft(2, '0')}';
  }
}
