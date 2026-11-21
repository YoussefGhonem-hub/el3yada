import 'package:material_ui/material_ui.dart';

import '../../../core/data/paged_controller.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../patients/presentation/widgets/clinic_ui.dart' show GroupedRows;

/// A list loaded page by page (25 per page, spec section 12), inside one
/// grouped card: skeleton, empty state, error with Retry, pull to refresh, and
/// the next page when the end is near. [header] scrolls with the list.
class PagedGroupedList<T> extends StatelessWidget {
  const PagedGroupedList({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onRetry,
    required this.empty,
    this.header,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 32),
    this.skeletonRow,
  });

  final PagedState<T> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final WidgetBuilder empty;
  final Widget? header;
  final Widget? footer;
  final EdgeInsets padding;

  /// One placeholder row while the first page loads.
  final Widget? skeletonRow;

  @override
  Widget build(BuildContext context) => StateSwitcher(
    state: state.view,
    loading: (context) => SkeletonLoading(
      loading: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        children: [
          ?header,
          if (skeletonRow != null)
            GroupedRows(children: [for (var i = 0; i < 5; i++) skeletonRow!]),
        ],
      ),
    ),
    empty: (context) =>
        ListView(padding: padding, children: [?header, empty(context)]),
    error: (context) => AdminErrorView(error: state.error!, onRetry: onRetry),
    content: (context) => RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) onLoadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: [
            ?header,
            GroupedRows(
              children: [
                for (final item in state.items) itemBuilder(context, item),
              ],
            ),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.moreError != null)
              AdminErrorView(
                error: state.moreError!,
                onRetry: onLoadMore,
                compact: true,
              ),
            ?footer,
          ],
        ),
      ),
    ),
  );
}
