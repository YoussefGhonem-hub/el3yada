import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/patient_providers.dart';
import '../../domain/patient_models.dart';
import '../patient_format.dart';

/// Keeps phone-first content readable on tablets: centred, at most [maxWidth] wide.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// Loading, error (with Retry) and data states of an [AsyncValue].
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, required this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncValue(:final value?, hasValue: true) => data(value),
      AsyncValue(:final error?) => ErrorState(error: error, onRetry: onRetry),
      _ => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
    };
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final network = ApiError.from(error).isNetwork;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(network ? Icons.wifi_off_outlined : Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(l10n.apiErrorMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// "New" badge on items the patient hasn't opened (P1).
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
      child: Text(
        context.l10n.newBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// كشف (blue) / استشارة (green), from the theme tokens.
class VisitTypeBadge extends StatelessWidget {
  const VisitTypeBadge({super.key, required this.type});

  final VisitType type;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final (background, foreground) = switch (type) {
      VisitType.examination => (colors.examination, colors.onExamination),
      VisitType.consultation => (colors.consultation, colors.onConsultation),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        context.visitType(type),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A titled card section used across the patient screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon, this.trailing, this.onTap});

  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 20, color: theme.colorScheme.primary), const SizedBox(width: 8)],
                  Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                  ?trailing,
                  if (onTap != null) Icon(Icons.chevron_right, color: theme.colorScheme.outline, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A label and a value, for detail screens.
class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          SelectableText(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// An attachment image fetched with the user's token (files are never public URLs).
class AuthedImage extends ConsumerWidget {
  const AuthedImage({super.key, required this.file, this.fit = BoxFit.cover, this.fallbackIcon = Icons.insert_drive_file_outlined});

  final FileRef file;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = ref.watch(fileBytesProvider(file));
    return switch (bytes) {
      AsyncValue(:final value?, hasValue: true) => Image.memory(
          value,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => Icon(fallbackIcon, color: scheme.outline),
        ),
      AsyncValue(hasError: true) => Icon(fallbackIcon, color: scheme.outline),
      _ => const Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    };
  }
}

/// Thumbnail of a file: its image, or an icon for PDFs and other types.
class FileThumb extends StatelessWidget {
  const FileThumb({super.key, required this.recordId, required this.cover, this.size = 56});

  final String recordId;
  final Attachment? cover;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = this.cover;
    final Widget content;
    if (cover != null && (cover.hasThumbnail || cover.isImage)) {
      content = AuthedImage(file: FileRef.attachment(recordId, cover.id, thumbnail: cover.hasThumbnail));
    } else {
      content = Icon(
        cover?.isPdf == true ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
        color: scheme.primary,
        size: size * 0.45,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(width: size, height: size, color: scheme.surfaceContainerHighest, child: content),
    );
  }
}

/// All / Dr A / Dr B chips (P1), shown only when the patient has more than one doctor.
class DoctorSelector extends ConsumerWidget {
  const DoctorSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(myDoctorsProvider).value ?? const <MyDoctor>[];
    if (doctors.length < 2) return const SizedBox.shrink();
    final selected = ref.watch(selectedDoctorProvider);
    final controller = ref.read(selectedDoctorProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.l10n.allDoctors),
            selected: selected == null,
            onSelected: (_) => controller.select(null),
          ),
          for (final d in doctors) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.doctorName(d.doctor)),
              selected: selected == d.doctor.id,
              onSelected: (_) => controller.select(d.doctor.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// Calls [onEnd] when the list is scrolled near its end (infinite scroll).
class LoadMoreListener extends StatelessWidget {
  const LoadMoreListener({super.key, required this.onEnd, required this.child});

  final VoidCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) onEnd();
          return false;
        },
        child: child,
      );
}

/// The footer of a paged list: a spinner while loading, or Retry after a failure.
class PagedFooter extends StatelessWidget {
  const PagedFooter({super.key, required this.state, required this.onRetry});

  final PagedState<Object?> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    if (state.loadMoreError != null) {
      return Center(child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.l10n.retry)));
    }
    return const SizedBox(height: 24);
  }
}
