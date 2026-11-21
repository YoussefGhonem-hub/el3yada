import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart' show noRetry;
import '../data/records_repository.dart';
import '../domain/record_models.dart';

/// D6 Files tab: one patient's records in one category (or all), page by
/// page, with the counts for the category chips.
final recordListProvider =
    NotifierProvider.autoDispose.family<RecordListController, RecordListState, RecordFilter>(RecordListController.new);

class RecordListState {
  const RecordListState({
    this.items = const [],
    this.totalCount = 0,
    this.counts,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.moreError,
  });

  final List<MedicalRecordView> items;
  final int totalCount;

  /// Null until the first page arrives.
  final RecordCounts? counts;
  final bool loading;
  final bool loadingMore;
  final Object? error;
  final Object? moreError;

  bool get hasMore => items.length < totalCount;
}

class RecordListController extends Notifier<RecordListState> {
  RecordListController(this.filter);

  final RecordFilter filter;
  static const pageSize = 25;
  int _request = 0;

  @override
  RecordListState build() {
    Future.microtask(reload);
    return const RecordListState();
  }

  /// Page 1 again. [keep] leaves the current items on screen meanwhile.
  Future<void> reload({bool keep = false}) async {
    if (!ref.mounted) return;
    final request = ++_request;
    if (!keep) state = RecordListState(counts: state.counts);
    try {
      final page = await ref.read(recordsRepositoryProvider).records(filter.patientId, category: filter.category, pageSize: pageSize);
      if (!ref.mounted || request != _request) return;
      state = RecordListState(items: page.items, totalCount: page.totalCount, counts: page.counts, loading: false);
    } catch (error) {
      if (!ref.mounted || request != _request) return;
      state = RecordListState(items: keep ? state.items : const [], counts: state.counts, loading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.loading || current.loadingMore || !current.hasMore) return;
    state = RecordListState(items: current.items, totalCount: current.totalCount, counts: current.counts, loading: false, loadingMore: true);
    try {
      final page = await ref.read(recordsRepositoryProvider).records(
            filter.patientId,
            category: filter.category,
            page: current.items.length ~/ pageSize + 1,
            pageSize: pageSize,
          );
      if (!ref.mounted) return;
      final seen = {for (final r in current.items) r.recordId};
      state = RecordListState(
        items: [...current.items, ...page.items.where((r) => !seen.contains(r.recordId))],
        totalCount: page.totalCount,
        counts: page.counts,
        loading: false,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = RecordListState(items: current.items, totalCount: current.totalCount, counts: current.counts, loading: false, moreError: error);
    }
  }
}

/// D12: one record.
final recordProvider = FutureProvider.autoDispose.family<MedicalRecordView, String>(
  (ref, recordId) => ref.watch(recordsRepositoryProvider).record(recordId),
  retry: noRetry,
);

/// The small JPEG of one file, for the list (never the file itself).
final recordThumbnailProvider = FutureProvider.autoDispose.family<Uint8List?, ({String recordId, String attachmentId})>(
  (ref, key) => ref.watch(recordsRepositoryProvider).thumbnail(key.recordId, key.attachmentId),
  retry: noRetry,
);

/// The bytes of one file, for the viewer (D12).
final recordFileProvider = FutureProvider.autoDispose.family<Uint8List, ({String recordId, String attachmentId})>(
  (ref, key) => ref.watch(recordsRepositoryProvider).download(key.recordId, key.attachmentId),
  retry: noRetry,
);

/// After a record was added, edited or deleted: the lists and the record
/// load again.
void recordsChanged(WidgetRef ref, {String? recordId}) {
  ref.invalidate(recordListProvider);
  if (recordId != null) ref.invalidate(recordProvider(recordId));
}
