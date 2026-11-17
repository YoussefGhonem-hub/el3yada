import 'package:flutter/material.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../records/presentation/record_text.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_files.dart';
import '../domain/catalog_models.dart';

/// Labels for the catalog screens (D0, AD19, AD20, the sources screen).
extension CatalogText on AppLocalizations {
  String catalogFailureText(CatalogFailure? failure) => switch (failure) {
    CatalogFailure.network || null => catalogFailureNetwork,
    CatalogFailure.server => catalogFailureServer,
    CatalogFailure.checksum => catalogFailureChecksum,
    CatalogFailure.corrupt => catalogFailureCorrupt,
    CatalogFailure.schema => catalogFailureSchema,
    CatalogFailure.storage => catalogFailureStorage,
  };

  String catalogTypeName(CatalogItemType type) => switch (type) {
    CatalogItemType.drug => catalogTypeDrug,
    CatalogItemType.lab => catalogTypeLab,
    CatalogItemType.radiology => catalogTypeRadiology,
  };

  String catalogReportTypeName(CatalogReportType type) => switch (type) {
    CatalogReportType.missing => catalogReportMissing,
    CatalogReportType.wrong => catalogReportWrong,
    CatalogReportType.other => catalogReportOther,
  };

  /// The drug dataset's routes in words; unknown ones as written.
  String catalogRouteName(String route) => switch (route) {
    'ORAL.SOLID' => catalogRouteOralSolid,
    'ORAL.LIQUID' => catalogRouteOralLiquid,
    'INJECTION' => catalogRouteInjection,
    'TOPICAL' => catalogRouteTopical,
    'EFF' => catalogRouteEffervescent,
    'RECTAL' => catalogRouteRectal,
    'EYE' => catalogRouteEye,
    'EAR' => catalogRouteEar,
    'SPRAY' => catalogRouteSpray,
    'VAGINAL' => catalogRouteVaginal,
    'MOUTH' => catalogRouteMouth,
    'SOAP' => catalogRouteSoap,
    'UNKNOWN' => catalogRouteUnknown,
    _ => route,
  };

  /// «7.2 ميجا».
  String catalogSize(int bytes) => fileSize(bytes);

  /// publishCatalog's errors (AD20), then the shared ones.
  String catalogPublishError(Object error) {
    if (error is ApiException) {
      final codes = {...error.fieldCodes.values, ?error.code};
      if (codes.contains('CATALOG_SHA_MISMATCH')) return catalogErrorShaMismatch;
      if (codes.contains('CATALOG_FILE_INVALID')) return catalogErrorFileInvalid;
      if (codes.contains('CATALOG_SCHEMA_UNSUPPORTED')) {
        final expected = '${error.details['expected'] ?? ''}';
        final actual = '${error.details['actual'] ?? ''}';
        return catalogErrorSchema(actual, expected);
      }
      if (codes.contains('CATALOG_NOT_PUBLISHED')) return catalogNotPublished;
      if (error.fieldCodes['manifest'] != null) return catalogErrorManifest;
      if (codes.contains('REQUEST_TOO_LARGE')) return catalogErrorTooLarge;
    }
    return apiError(error);
  }
}

/// The icon of an item type.
IconData catalogTypeIcon(CatalogItemType type) => switch (type) {
  CatalogItemType.drug => Icons.medication_outlined,
  CatalogItemType.lab => Icons.biotech_outlined,
  CatalogItemType.radiology => Icons.settings_overscan_outlined,
};

/// One line about the catalog on this device (Settings, AD20).
String catalogStatus(AppLocalizations l10n, CatalogState state) {
  final installed = state.installed;
  return switch (state.phase) {
    CatalogPhase.downloading => l10n.catalogPhaseDownloading('${((state.progress ?? 0) * 100).floor()}'),
    CatalogPhase.verifying => l10n.catalogPhaseVerifying,
    CatalogPhase.checking when installed == null => l10n.catalogPhaseChecking,
    CatalogPhase.failed when installed == null => l10n.catalogStatusFailed,
    CatalogPhase.notPublished => l10n.catalogStatusNotPublished,
    CatalogPhase.idle || CatalogPhase.unavailable when installed == null => l10n.catalogStatusUnavailable,
    _ => installed == null ? l10n.catalogStatusUnavailable : l10n.catalogStatusReady('${installed.version}'),
  };
}
