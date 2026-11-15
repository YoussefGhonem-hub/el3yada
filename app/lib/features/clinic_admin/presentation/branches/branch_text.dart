import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/branch_models.dart';
import '../../domain/weekly_hours.dart';
import '../widgets/clinic_admin_widgets.dart';

/// Names for branch values (D28, D29) in the current language.
extension BranchText on AppLocalizations {
  String branchStatusName(String status) => switch (status) {
        BranchStatuses.temporarilyClosed => clinicBranchTemporarilyClosed,
        BranchStatuses.archived => branchStatusArchived,
        _ => branchStatusActive,
      };

  String paymentMethodName(String method) => switch (method) {
        'cash' => branchPayCash,
        'card' => branchPayCard,
        'instapay' => branchPayInstapay,
        'wallet' => branchPayWallet,
        _ => method,
      };

  String amenityName(String amenity) => switch (amenity) {
        'elevator' => branchAmenityElevator,
        'parking' => branchAmenityParking,
        'wheelchair' => branchAmenityWheelchair,
        'kidsArea' => branchAmenityKidsArea,
        _ => amenity,
      };

  String phoneLabelName(String label) => switch (label) {
        PhoneLabels.mobile => regPhoneTypeMobile,
        PhoneLabels.landline => regPhoneTypeLandline,
        _ => regPhoneTypeReception,
      };

  String visitTypeName(String type) => type == 'consultation' ? regConsultationPrice : regExaminationPrice;
}

/// The weekday's name (ISO 1–7) in the current language: «السبت», "Saturday".
String weekdayName(BuildContext context, int weekday) {
  // 2024-01-01 was a Monday.
  final day = DateTime(2024, 1, weekday);
  return DateFormat.EEEE(Localizations.localeOf(context).languageCode).format(day);
}

/// A Cairo "HH:mm" as the clock reads in the current language: «10:00 ص», "10:00 AM".
String clockText(BuildContext context, String hhmm) {
  final minutes = WeeklyHours.parse(hhmm);
  if (minutes == null) return hhmm;
  final time = DateTime(2024, 1, 1, minutes ~/ 60, minutes % 60);
  return DateFormat.jm(Localizations.localeOf(context).languageCode).format(time);
}

/// «10:00 ص – 2:00 م», with «(اليوم التالي)» for a period past midnight.
String periodText(BuildContext context, BranchPeriod period) {
  final l10n = AppLocalizations.of(context);
  final range = l10n.adminDateRange(clockText(context, period.startLocal), clockText(context, period.endLocal));
  return period.endsNextDay ? l10n.branchEndsNextDayShort(range) : range;
}

/// A Cairo calendar day: «25 نوفمبر 2026».
String dayText(BuildContext context, DateTime day) =>
    DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(day);

/// The status as a pill: open (green), temporarily closed (coral), archived.
class BranchStatusPill extends StatelessWidget {
  const BranchStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: AppLocalizations.of(context).branchStatusName(status),
        tone: switch (status) {
          BranchStatuses.active => PillTone.positive,
          BranchStatuses.temporarilyClosed => PillTone.warning,
          _ => PillTone.neutral,
        },
        icon: switch (status) {
          BranchStatuses.active => Icons.check_circle_outline,
          BranchStatuses.temporarilyClosed => Icons.pause_circle_outline,
          _ => Icons.inventory_2_outlined,
        },
      );
}

/// The «افتراضي» badge on the default branch (BR-BR3), in the mint of the
/// selected menu item.
class DefaultBranchPill extends StatelessWidget {
  const DefaultBranchPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    return DecoratedBox(
      decoration: ShapeDecoration(color: colors.navIndicator, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(Icons.star_rounded, size: 14, color: colors.onNavIndicator)),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).branchDefault,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.onNavIndicator, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
