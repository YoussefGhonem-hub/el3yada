import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/navigation/app_back_button.dart';
import '../../core/widgets/navigation/app_bottom_bar.dart';
import '../../core/widgets/navigation/desktop_page_header.dart';
import '../../core/widgets/navigation/nav_item.dart';
import '../../core/widgets/navigation/nav_rail.dart';
import '../../core/widgets/navigation/side_menu.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/settings_actions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/application/auth_controller.dart';
import '../auth/domain/user_role.dart';
import '../clinic/application/clinic_providers.dart';
import '../admin/presentation/widgets/admin_widgets.dart' show InitialAvatar;
import '../clinic/presentation/clinic_shell_parts.dart';
import 'role_shells.dart';
import 'shell_navigator_watch.dart';

/// Badge on a destination, by its path (null for none). Nothing sets one yet;
/// the chats phase overrides it with the unread count, for example
/// `'/doctor/chats' => NavBadge.count(unread)`.
final navBadgeProvider = Provider.family<NavBadge?, String>((ref, path) => null);

/// Adaptive frame around every signed-in screen (spec section 4):
/// - phone (< 600): a full-width bottom bar of icons around the app logo,
///   which opens the dashboard (see [RoleShell.centerOf]), plus More
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
    this.navigatorWatch,
    this.branchIndex = 0,
  });

  final RoleShell shell;
  final String location;
  final Widget child;

  /// The tab navigators, so Back shows on every screen above a tab's root,
  /// including screens opened without an address. Null shows Back by
  /// address only.
  final ShellNavigatorWatch? navigatorWatch;

  /// The tab on screen, for [navigatorWatch].
  final int branchIndex;

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
  void didUpdateWidget(RoleScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _barHidden.value = false;
    if (!identical(oldWidget.navigatorWatch, widget.navigatorWatch)) {
      oldWidget.navigatorWatch?.removeListener(_onRouteChanged);
      widget.navigatorWatch?.addListener(_onRouteChanged);
    }
  }

  /// The router, watched so the top bar's Back follows screens opened with
  /// `push` too: the shell's own [RoleScaffold.location] doesn't change for
  /// those.
  GoRouterDelegate? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context)?.routerDelegate;
    if (identical(router, _router)) return;
    _router?.removeListener(_onRouteChanged);
    _router = router?..addListener(_onRouteChanged);
  }

  @override
  void initState() {
    super.initState();
    widget.navigatorWatch?.addListener(_onRouteChanged);
    if (_isClinic) {
      _lifecycle = AppLifecycleListener(onResume: () => ref.read(clinicContextProvider.notifier).reload());
    }
  }

  void _onRouteChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// The address of the screen on top, including pushed screens.
  String get _topLocation {
    final router = _router;
    if (router == null || router.currentConfiguration.isEmpty) return widget.location;
    return router.state.uri.path;
  }

  @override
  void dispose() {
    _router?.removeListener(_onRouteChanged);
    widget.navigatorWatch?.removeListener(_onRouteChanged);
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
    // Back: on a screen above the tab's root (by address, or on the tab's
    // navigator), and on items that live under More.
    final top = _topLocation;
    final phone = width < Breakpoints.tablet;
    final backTo = shell.backTarget(
          top,
          menuShowsAll: width >= Breakpoints.desktop,
          center: phone && visible.isNotEmpty ? shell.centerOf(visible).path : null,
        ) ??
        (widget.navigatorWatch?.canPop(widget.branchIndex) ?? false ? shell.destinationAt(top)?.path ?? shell.morePath : null);
    final appBar = AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      // Back on every screen below a menu root; the app mark on the roots.
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16),
        child: Center(
          child: AnimatedSwitcher(
            duration: Motion.normal,
            reverseDuration: Motion.fastExit,
            switchInCurve: Motion.springBouncy,
            switchOutCurve: Motion.exitCurveReversed,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation.drive(Tween(begin: 0.6, end: 1)), child: child),
            ),
            child: backTo != null
                ? AppBackButton(key: const ValueKey('back'), fallback: backTo)
                : const _AppMark(key: ValueKey('mark')),
          ),
        ),
      ),
      titleSpacing: 4,
      // Phones drop the role from the title, so it fits next to the branch picker.
      title: Text(
        clinicTitle(l10n, languageCode, clinic) ??
            (width < Breakpoints.tablet ? l10n.appTitle : '${l10n.appTitle} · ${shell.role.label(l10n)}'),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (_isClinic) _PillButtons(child: BranchPicker(compact: width < Breakpoints.tablet)),
        if (profilePath != null && session != null)
          _ProfileButton(
            name: displayName,
            tooltip: l10n.profileTopBarTooltip,
            onTap: () => context.go(profilePath),
          ),
        // Phones have little room: doctors, assistants and admins change the
        // language and theme, and sign out, in their settings (D24, AS12,
        // AD18). Patients keep them here until their account screen (P14).
        if (width >= Breakpoints.tablet || shell.role == UserRole.patient) const SettingsActions(),
        const SizedBox(width: 8),
      ],
    );

    // The suspension banner (BR-G5, BR-G8), the trial countdown (BR-T6), "Verify your email" (A5) and the offline notice sit above
    // every clinic screen. The top bar shows Back, so screens don't.
    final content = ShellBackScope(
      child: !_isClinic
          ? widget.child
          : Column(
              children: [
                SuspensionBanner(billingPath: '${shell.basePath}/billing'),
                const TrialBanner(),
                const EmailVerifyBanner(),
                const ClinicLoadError(),
                Expanded(child: widget.child),
              ],
            ),
    );

    NavItem itemFor(NavDestinationSpec d, {bool bar = false}) => NavItem(
          icon: d.icon,
          selectedIcon: d.selectedIcon,
          label: (bar ? d.barLabel : null)?.call(l10n) ?? d.label(l10n),
          badge: ref.watch(navBadgeProvider(d.path)),
        );

    if (width >= Breakpoints.desktop) {
      // Desktop: no top bar. The side menu (the ticket's stub) holds the
      // brand and the account; the page has its own header with Back, named
      // after the section it returns to, the branch and quick settings.
      final all = visible;
      final firstSecondary = all.indexWhere((d) => !d.primary);
      final backLabel = shell.destinationAt(top)?.label(l10n) ?? MaterialLocalizations.of(context).backButtonTooltip;
      return CallbackShortcuts(
        bindings: {
          // Alt+Left goes back, as in a browser.
          if (backTo != null)
            const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
                AppBackButton.goBack(context, fallback: backTo),
        },
        child: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSideMenu(
                items: [for (final d in all) itemFor(d)],
                selectedIndex: all.indexWhere((d) => location.startsWith(d.path)),
                onSelected: (i) => context.go(all[i].path),
                breaks: {if (firstSecondary > 0) firstSecondary},
                // The clinic under the name; admins see their role on the
                // account card below.
                header: SideMenuBrand(
                  title: l10n.appTitle,
                  subtitle: clinic == null ? null : l10n.clinicOfDoctor(clinic.doctor.name(languageCode)),
                ),
                footer: session == null
                    ? null
                    : SideMenuAccount(
                        name: displayName,
                        initial: InitialAvatar.initialOf(displayName),
                        role: shell.role.label(l10n),
                        onProfile: profilePath == null ? null : () => context.go(profilePath),
                        onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopPageHeader(
                      back: backTo == null ? null : AppBackButton(key: ValueKey(backLabel), fallback: backTo, label: backLabel),
                      trailing: [
                        if (_isClinic) const _DesktopPill(child: BranchPicker()),
                        const DesktopQuickSettings(),
                      ],
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
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
    NavItem moreItem() => NavItem(
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          label: l10n.navMore,
          badge: moreHasBadge ? const NavBadge.dot() : null,
        );
    List<NavItem> items({required bool bar}) => [
          for (final d in primary) itemFor(d, bar: bar),
          if (hasMore) moreItem(),
        ];
    void onSelected(int i) => context.go(i < primary.length ? primary[i].path : shell.morePath);

    if (width < Breakpoints.tablet) {
      // Phones: the logo in the middle opens the dashboard (or the home);
      // the other bar items and More sit on both sides of it.
      final center = shell.centerOf(visible);
      final sides = primary.where((d) => d != center).toList();
      final centerSelected = center.covers(location);
      var sideIndex = sides.indexWhere((d) => d.covers(location));
      if (sideIndex < 0 && !centerSelected && hasMore) sideIndex = sides.length;
      return Scaffold(
        appBar: appBar,
        // Content scrolls behind the bar's rounded corners; lists get its
        // height as bottom padding from MediaQuery.
        extendBody: true,
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onUserScroll,
          child: content,
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: _barHidden,
          builder: (context, hidden, _) => AppBottomBar(
            items: [
              for (final d in sides) itemFor(d, bar: true),
              if (hasMore) moreItem(),
            ],
            selectedIndex: sideIndex,
            onSelected: (i) => context.go(i < sides.length ? sides[i].path : shell.morePath),
            center: BottomBarCenter(
              label: center.label(l10n),
              selected: centerSelected,
              onTap: () => context.go(center.path),
            ),
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

/// The app's mark on a pine tile, in the top bar of menu roots.
class _AppMark extends StatelessWidget {
  const _AppMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B6B5D), AppColors.pine],
          ),
          boxShadow: [
            BoxShadow(color: AppColors.pine.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const AppLogoMark(size: 30, letterColor: Colors.white, plusColor: AppColors.mint),
      );
}

/// The user's initial in a teal-to-pine circle; opens their profile.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.name, required this.tooltip, required this.onTap});

  final String name;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: Tooltip(
          message: tooltip,
          child: Pressable(
            onTap: onTap,
            semanticLabel: tooltip,
            pressedScale: 0.9,
            borderRadius: BorderRadius.circular(19),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2BB594), AppColors.pine],
                ),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerLowest, width: 2),
                boxShadow: [
                  BoxShadow(color: AppColors.pine.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Text(
                InitialAvatar.initialOf(name),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1),
              ),
            ),
          ),
        ),
      );
}

/// Gives the text buttons inside (the branch picker) a white pill look.
class _PillButtons extends StatelessWidget {
  const _PillButtons({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLowest,
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
          textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      child: child,
    );
  }
}

/// The desktop header's branch picker: a pill like the quick settings next
/// to it, with the store icon in the brand colour.
class _DesktopPill extends StatelessWidget {
  const _DesktopPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          foregroundColor: scheme.onSurface,
          iconColor: scheme.primary,
          minimumSize: const Size(48, DesktopQuickSettings.height),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
          textStyle: theme.textTheme.labelLarge,
        ),
      ),
      child: child,
    );
  }
}
