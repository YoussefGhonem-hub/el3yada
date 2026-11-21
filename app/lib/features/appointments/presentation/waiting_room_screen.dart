import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../patient/presentation/patient_format.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment_models.dart';

/// D36 [C] (BR-LB7): a full-screen view for a TV in the waiting room. It shows "now serving" and the next
/// numbers only, never names, and follows the board live (SignalR, with the 15-second refresh as fallback).
/// It opens from the board's menu on desktop and tablet.
class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key, required this.branchId, required this.basePath});

  final String branchId;

  /// `/doctor` or `/assistant`: where Exit goes when there is nothing to go back to.
  final String basePath;

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  @override
  void initState() {
    super.initState();
    // Phones and tablets hide the system bars; desktop windows are left as they are.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('${widget.basePath}/live');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final board = ref.watch(boardProvider(widget.branchId));
    final branch = ref.watch(staffBranchesProvider).value?.where((b) => b.id == widget.branchId).firstOrNull;
    final snapshot = board.value?.snapshot;
    final offline = board.value?.offline ?? false;

    return Scaffold(
      backgroundColor: scheme.primaryContainer,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: snapshot == null
                  ? Center(child: CircularProgressIndicator(color: scheme.onPrimaryContainer))
                  : _Numbers(snapshot: snapshot),
            ),
            PositionedDirectional(
              top: 8,
              start: 16,
              end: 64,
              child: Text(
                branch?.displayName(arabic: context.isArabic) ?? '',
                style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton(
                tooltip: l10n.waitingRoomExit,
                onPressed: _exit,
                icon: Icon(Icons.fullscreen_exit, color: scheme.onPrimaryContainer),
              ),
            ),
            if (offline)
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: scheme.errorContainer,
                  child: Text(l10n.boardOffline, textAlign: TextAlign.center, style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.snapshot});

  final BoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motion = Motion.of(context);
    final next = snapshot.nextNumbers;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sized for the room: the big number takes about a third of the screen's height.
        final big = (constraints.maxHeight * 0.32).clamp(72.0, 360.0);
        final small = (big * 0.32).clamp(28.0, 112.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.nowServing, style: theme.textTheme.headlineMedium?.copyWith(color: scheme.onPrimaryContainer)),
            AnimatedSwitcher(
              duration: motion.reduced ? Duration.zero : Motion.slow,
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurve,
              transitionBuilder: (child, animation) => motion.reduced
                  ? FadeTransition(opacity: animation, child: child)
                  : ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(animation), child: FadeTransition(opacity: animation, child: child)),
              child: Text(
                snapshot.nowServing == null ? '–' : '${snapshot.nowServing}',
                key: ValueKey(snapshot.nowServing),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: big,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(next.isEmpty ? l10n.boardNoOneWaiting : l10n.waitingRoomNext,
                style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final n in next)
                  Container(
                    key: ValueKey('next-$n'),
                    padding: EdgeInsets.symmetric(horizontal: small * 0.6, vertical: small * 0.2),
                    decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(small * 0.4)),
                    child: Text('$n', style: theme.textTheme.displaySmall?.copyWith(fontSize: small, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
