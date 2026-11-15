import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/navigation/floating_nav_bar.dart';
import '../../core/widgets/navigation/nav_item.dart';
import '../../core/widgets/navigation/nav_rail.dart';
import '../../core/widgets/navigation/side_menu.dart';
import '../../core/widgets/settings_actions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/application/auth_controller.dart';
import '../auth/domain/user_role.dart';
import '../clinic/application/clinic_providers.dart';
import '../clinic/presentation/clinic_shell_parts.dart';
import 'role_shells.dart';

/// Badge on a destination, by its path (null for none). Nothing sets one yet;
/// the chats phase overrides it with the unread count, for example
/// `'/doctor/chats' => NavBadge.count(unread)`.
final navBadgeProvider = Provider.family<NavBadge?, String>((ref, path) => null);

/// Adaptive frame around every signed-in screen (spec section 4):
/// - phone (< 600): floating bottom bar with the primary items + More
/// - tablet (600–1024): navigation rail with the same items
/// - desktop (≥ 1024): side menu with every item
///
/// All three share the sliding mint indicator. On phones the bar hides while
/// the keyboard is open and while the content scrolls down.
class RoleScaffold extends ConsumerStatefulWidget {
  const RoleScaffold({
    super.key,
    required this.shell,
    required this.location,
    required this.child,
  });

  final RoleShell shell;
  final String location;
  final Widget child;

  @override
  ConsumerState<RoleScaffold> createState() => _RoleScaffoldState();
}

class _RoleScaffoldState extends ConsumerState<RoleScaffold> {
  /// [S] The phone bar slides away while content scrolls down.
  final _barHidden = ValueNotifier<bool>(false);

  /// Doctors and assistants: the clinic is read again on resume, since the
  /// doctor can change an assistant's permissions at any time (BR-AS4).
  AppLifecycleListener? _lifecycle;

  bool get _isClinic => widget.shell.role == UserRole.doctor || widget.shell.role == UserRole.assistant;

  @override
  void initState() {
    super.initState();
    if (_isClinic) {
      _lifecycle = AppLifecycleListener(onResume: () => ref.read(clinicContextProvider.notifier).reload());
    }
  }

  @override
  void didUpdateWidget(RoleScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _barHidden.value = false;
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _barHidden.dispose();
    super.dispose();
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      switch (notification.direction) {
        case ScrollDirection.reverse:
          _barHidden.value = true;
        case ScrollDirection.forward:
          _barHidden.value = false;
        case ScrollDirection.idle:
          break;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = widget.shell;
    final location = widget.location;
    final width = MediaQuery.sizeOf(context).width;
    final session = ref.watch(authControllerProvider).value;
    final clinic = _isClinic ? ref.watch(clinicContextProvider).value : null;
    final displayName = session?.displayName ?? '';
    // Items the user may not use (AD14 for a plain admin, an assistant's
    // items without the permission) aren't shown.
    final visible = shell.visibleTo(session, clinic: clinic);
    final profilePath = shell.profilePath;
    final languageCode = Localizations.localeOf(context).languageCode;
    final appBar = AppBar(
      title: Text(clinicTitle(l10n, languageCode, clinic) ?? '${l10n.appTitle} · ${shell.role.label(l10n)}'),
      actions: [
        if (_isClinic) BranchPicker(compact: width < Breakpoints.tablet),
        if (profilePath != null && session != null)
          IconButton(
            tooltip: l10n.profileTopBarTooltip,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go(profilePath),
          ),
        // Phones have little room: doctors, assistants and admins change the
        // language and theme, and sign out, in their settings (D24, AS12,
        // AD18). Patients keep them here until their account screen (P14).
        if (width >= Breakpoints.tablet || shell.role == UserRole.patient) const SettingsActions(),
      ],
    );

    // The suspension banner (BR-G5, BR-G8) and the offline notice sit above
    // every clinic screen.
    final content = !_isClinic
        ? widget.child
        : Column(
            children: [
              SuspensionBanner(billingPath: '${shell.basePath}/billing'),
              const ClinicLoadError(),
              Expanded(child: widget.child),
            ],
          );

    NavItem itemFor(NavDestinationSpec d, {bool bar = false}) => NavItem(
          icon: d.icon,
          selectedIcon: d.selectedIcon,
          label: (bar ? d.barLabel : null)?.call(l10n) ?? d.label(l10n),
          badge: ref.watch(navBadgeProvider(d.path)),
        );

    if (width >= Breakpoints.desktop) {
      final all = visible;
      return Scaffold(
        appBar: appBar,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSideMenu(
              items: [for (final d in all) itemFor(d)],
              selectedIndex: all.indexWhere((d) => location.startsWith(d.path)),
              onSelected: (i) => context.go(all[i].path),
              header: displayName.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
                      child: Text(displayName, style: Theme.of(context).textTheme.titleSmall),
                    ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    final primary = visible.where((d) => d.primary).toList();
    final secondary = visible.where((d) => !d.primary).toList();
    final hasMore = shell.secondary.isNotEmpty;
    var index = primary.indexWhere((d) => location.startsWith(d.path));
    if (index < 0) index = hasMore ? primary.length : 0;

    // "More" shows a dot when something inside it has a badge.
    final moreHasBadge = secondary.any((d) => NavBadgeView.isVisible(ref.watch(navBadgeProvider(d.path))));
    List<NavItem> items({required bool bar}) => [
          for (final d in primary) itemFor(d, bar: bar),
          if (hasMore)
            NavItem(
              icon: Icons.more_horiz,
              selectedIcon: Icons.more_horiz,
              label: l10n.navMore,
              badge: moreHasBadge ? const NavBadge.dot() : null,
            ),
        ];
    void onSelected(int i) => context.go(i < primary.length ? primary[i].path : shell.morePath);

    if (width < Breakpoints.tablet) {
      return Scaffold(
        appBar: appBar,
        // Content scrolls behind the floating bar; lists get its height as
        // bottom padding from MediaQuery.
        extendBody: true,
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onUserScroll,
          child: content,
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _barHidden,
          builder: (context, hidden, _) => FloatingNavBar(
            items: items(bar: true),
            selectedIndex: index,
            onSelected: onSelected,
            hidden: hidden,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNavRail(items: items(bar: false), selectedIndex: index, onSelected: onSelected),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}
