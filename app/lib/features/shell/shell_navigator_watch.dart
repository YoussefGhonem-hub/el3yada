import 'package:flutter/widgets.dart';

/// Watches the tab navigators of one role area, so its top bar can show Back
/// on every screen above a tab's root: screens with an address
/// (`/doctor/patients/42`) and screens opened without one, such as a card
/// that expands into its detail (`ContainerTransform`).
///
/// The router gives each tab (`StatefulShellBranch`) the observer from
/// [observerFor], and `RoleScaffold` listens to this watch.
class ShellNavigatorWatch extends ChangeNotifier {
  final Map<int, _BranchObserver> _observers = {};

  /// The observer for tab [index]. A navigator observer can serve one
  /// navigator only, so every tab has its own.
  NavigatorObserver observerFor(int index) => _observers.putIfAbsent(index, () => _BranchObserver(this));

  /// Whether tab [index] has a screen above its root.
  bool canPop(int index) => _observers[index]?.navigator?.canPop() ?? false;

  void _changed() => notifyListeners();
}

class _BranchObserver extends NavigatorObserver {
  _BranchObserver(this._watch);

  final ShellNavigatorWatch _watch;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _watch._changed();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _watch._changed();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _watch._changed();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _watch._changed();
}
