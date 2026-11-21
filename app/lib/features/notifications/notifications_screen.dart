import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../patient/presentation/patient_format.dart';
import '../patient/presentation/widgets/patient_widgets.dart';
import 'notifications.dart';

/// D21, P13, AS11, AD17: newest first, unread in bold, tap opens `data.route`, Mark all as read.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final page = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text(l10n.notificationsTitle, style: Theme.of(context).textTheme.titleLarge)),
              TextButton(
                onPressed: (page.value?.unreadCount ?? 0) > 0 ? controller.markAllRead : null,
                child: Text(l10n.markAllRead),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: AsyncValueView(
              value: page,
              onRetry: () => ref.invalidate(notificationsProvider),
              data: (data) => data.items.isEmpty
                  ? ListView(children: [EmptyState(icon: Icons.notifications_none, message: l10n.noNotifications)])
                  : LoadMoreListener(
                      onEnd: controller.loadMore,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: data.items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) => ContentWidth(
                          child: _NotificationTile(
                            notification: data.items[index],
                            onTap: () async {
                              final n = data.items[index];
                              await controller.markRead(n);
                              if (context.mounted && n.route != null) openRoute(context, n.route!);
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens a notification's route. Routes the app doesn't know (yet) are ignored, not crashed on.
void openRoute(BuildContext context, String route) {
  try {
    context.push(route);
  } catch (_) {}
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabic = context.isArabic;
    final unread = !notification.isRead;
    return ListTile(
      onTap: onTap,
      tileColor: unread ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
      leading: Icon(_icon(notification.type), color: unread ? theme.colorScheme.primary : theme.colorScheme.outline),
      title: Text(notification.title(arabic: arabic), style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w400)),
      subtitle: Text('${notification.body(arabic: arabic)}\n${context.dateTime(notification.createdAt)}'),
      isThreeLine: true,
    );
  }

  static IconData _icon(String type) => switch (type) {
        'chatMessage' => Icons.chat_bubble_outline,
        'prescriptionSent' || 'prescriptionCancelled' || 'draftReady' => Icons.receipt_long_outlined,
        'fileAdded' => Icons.folder_open_outlined,
        'sessionRecorded' => Icons.medical_services_outlined,
        final t when t.startsWith('booking') || t == 'doctorDelayed' || t == 'staffBookingActivity' => Icons.event_note_outlined,
        final t when t.startsWith('invoice') || t.startsWith('payment') => Icons.payments_outlined,
        _ => Icons.notifications_outlined,
      };
}

/// The bell in the top bar, with the unread count.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsProvider).value ?? 0;
    return IconButton(
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.go(path),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
