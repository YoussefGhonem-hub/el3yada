import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/motion.dart';

/// What a screen or section is showing.
enum ViewState { loading, content, empty, error }

/// Crossfades between loading, content, empty and error instead of snapping
/// (spec section 12). Only the current state is built. The crossfade stays
/// with reduced motion: it is a state change, not decoration.
///
/// ```dart
/// StateSwitcher(
///   state: ViewState.loading,
///   loading: (_) => SkeletonLoading(loading: true, child: PatientList.placeholder()),
///   content: (_) => PatientList(patients),
///   empty: (_) => EmptyState(title: l10n.noPatients, ...),
///   error: (_) => ErrorView(onRetry: refresh),
/// )
/// ```
///
/// With Riverpod, use [AsyncStateSwitcher].
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({
    super.key,
    required this.state,
    required this.loading,
    required this.content,
    this.empty,
    this.error,
    this.alignment = AlignmentDirectional.topCenter,
  });

  final ViewState state;
  final WidgetBuilder loading;
  final WidgetBuilder content;

  /// Falls back to [content] when null.
  final WidgetBuilder? empty;

  /// Falls back to [content] when null.
  final WidgetBuilder? error;

  /// Where the outgoing and incoming states line up during the crossfade.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final builder = switch (state) {
      ViewState.loading => loading,
      ViewState.content => content,
      ViewState.empty => empty ?? content,
      ViewState.error => error ?? content,
    };
    return AnimatedSwitcher(
      duration: Motion.normal,
      reverseDuration: Motion.normalExit,
      switchInCurve: Motion.enterCurve,
      switchOutCurve: Motion.exitCurveReversed,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        fit: StackFit.passthrough,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(state), child: Builder(builder: builder)),
    );
  }
}

/// [StateSwitcher] driven by a Riverpod [AsyncValue]. Loading shows
/// [loading] only when there is no previous value; a refresh keeps the
/// content on screen.
///
/// ```dart
/// AsyncStateSwitcher<List<Patient>>(
///   value: ref.watch(patientsProvider),
///   isEmpty: (patients) => patients.isEmpty,
///   loading: (_) => const PatientListSkeleton(),
///   data: (context, patients) => PatientList(patients),
///   empty: (_) => EmptyState(title: l10n.noPatients),
///   error: (context, error) => ErrorView(error, onRetry: ...),
/// )
/// ```
class AsyncStateSwitcher<T> extends StatelessWidget {
  const AsyncStateSwitcher({
    super.key,
    required this.value,
    required this.loading,
    required this.data,
    this.isEmpty,
    this.empty,
    this.error,
  });

  final AsyncValue<T> value;
  final WidgetBuilder loading;
  final Widget Function(BuildContext context, T data) data;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? empty;
  final Widget Function(BuildContext context, Object error)? error;

  @override
  Widget build(BuildContext context) {
    final current = value;
    final ViewState state;
    if (current.hasValue) {
      final empties = isEmpty?.call(current.requireValue) ?? false;
      state = empties && empty != null ? ViewState.empty : ViewState.content;
    } else if (current.hasError && error != null) {
      state = ViewState.error;
    } else {
      state = ViewState.loading;
    }
    return StateSwitcher(
      state: state,
      loading: loading,
      content: (context) => data(context, current.requireValue),
      empty: empty,
      error: error == null ? null : (context) => error!(context, current.error!),
    );
  }
}
