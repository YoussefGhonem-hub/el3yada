import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/shell/placeholder_pages.dart';
import '../features/shell/role_shells.dart';

/// The real screen behind each menu destination (role_shells.dart). A
/// destination not listed here shows a `PlaceholderPage`.
///
/// To add a screen, add its path here, and its detail screens (opened from
/// it, with Back) to [destinationRoutes]:
///
/// ```dart
/// '/admin/signups': (_) => const SignupRequestsScreen(),
/// ```
final Map<String, WidgetBuilder> _destinationScreens = {};

/// Detail routes under a destination, relative to it, for example
/// `GoRoute(path: ':doctorId', builder: ...)` under `/admin/signups`.
final Map<String, List<RouteBase>> _destinationRoutes = {};

Widget destinationPage(BuildContext context, NavDestinationSpec destination) =>
    _destinationScreens[destination.path]?.call(context) ?? PlaceholderPage(destination: destination);

List<RouteBase> destinationRoutes(NavDestinationSpec destination) => _destinationRoutes[destination.path] ?? const [];
