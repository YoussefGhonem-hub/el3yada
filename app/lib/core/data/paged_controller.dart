import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/state_switcher.dart';
import 'paged.dart';

/// Lists show their own error state with a Retry button, so a failed
/// request isn't retried in the background (Riverpod 3 retries by default).
Duration? noRetry(int retryCount, Object error) => null;

/// A list loaded page by page (25 per page, spec section 12).
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.totalCount = 0,
    this.loading = true,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
    this.moreError,
  });

  final List<T> items;
  final int totalCount;

  /// The first page is loading and nothing is shown yet.
  final bool loading;

  /// Page 1 is loading again while the current items stay on screen.
  final bool refreshing;
  final bool loadingMore;

  /// The first page failed.
  final Object? error;

  /// The next page failed; the items so far stay.
  final Object? moreError;

  bool get hasMore => items.length < totalCount;

  ViewState get view {
    if (loading) return ViewState.loading;
    if (items.isEmpty) return error != null ? ViewState.error : ViewState.empty;
    return ViewState.content;
  }

  PagedState<T> copyWith({
    List<T>? items,
    int? totalCount,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    Object? Function()? error,
    Object? Function()? moreError,
  }) =>
      PagedState(
        items: items ?? this.items,
        totalCount: totalCount ?? this.totalCount,
        loading: loading ?? this.loading,
        refreshing: refreshing ?? this.refreshing,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error == null ? this.error : error(),
        moreError: moreError == null ? this.moreError : moreError(),
      );
}

/// Loads a list page by page. Subclasses say how to [fetch] a page and how
/// to tell two items apart ([keyOf]). The first page loads when the
/// provider is first read.
///
/// Items removed locally (an approved sign-up) shift the server's pages, so
/// the next page is worked out from how many items are shown, and items
/// already shown are skipped.
abstract class PagedController<T> extends Notifier<PagedState<T>> {
  static const pageSize = 25;

  int _request = 0;

  Future<Paged<T>> fetch(int page, int pageSize);

  Object keyOf(T item);

  @override
  PagedState<T> build() {
    Future.microtask(reload);
    return PagedState<T>();
  }

  /// Starts again from page 1, showing the loading state.
  Future<void> reload() => _load(reset: true);

  /// Page 1 again, keeping the items on screen (pull to refresh).
  Future<void> refresh() => _load(reset: false);

  /// The next page, unless one is already loading or there is no more.
  Future<void> loadMore() async {
    final current = state;
    if (current.loading || current.refreshing || current.loadingMore || !current.hasMore) return;
    await _load(page: current.items.length ~/ pageSize + 1);
  }

  /// Drops items from the list without asking the server (after a review).
  void removeWhere(bool Function(T item) test) {
    final kept = state.items.where((item) => !test(item)).toList();
    final removed = state.items.length - kept.length;
    if (removed == 0) return;
    state = state.copyWith(items: kept, totalCount: (state.totalCount - removed).clamp(0, 1 << 31));
  }

  Future<void> _load({bool reset = false, int page = 1}) async {
    if (!ref.mounted) return;
    final request = ++_request;
    if (page == 1) {
      state = reset ? PagedState<T>() : state.copyWith(refreshing: true, error: () => null);
    } else {
      state = state.copyWith(loadingMore: true, moreError: () => null);
    }
    try {
      final result = await fetch(page, pageSize);
      if (!ref.mounted || request != _request) return;
      final items = page == 1 ? result.items : _merge(state.items, result.items);
      state = PagedState<T>(items: items, totalCount: result.totalCount, loading: false);
    } catch (error) {
      if (!ref.mounted || request != _request) return;
      state = page == 1
          ? state.copyWith(loading: false, refreshing: false, error: () => error)
          : state.copyWith(loadingMore: false, moreError: () => error);
    }
  }

  List<T> _merge(List<T> shown, List<T> next) {
    final keys = {for (final item in shown) keyOf(item)};
    return [...shown, ...next.where((item) => !keys.contains(keyOf(item)))];
  }
}
