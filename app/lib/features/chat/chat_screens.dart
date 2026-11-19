import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_error.dart';
import '../../core/platform/app_platform.dart';
import '../../core/platform/file_share.dart';
import '../../l10n/gen/app_localizations.dart';
import '../patient/presentation/patient_format.dart';
import '../patient/presentation/widgets/patient_widgets.dart';
import 'chat_data.dart';
import 'chat_providers.dart';

/// Thread route for the current area, for example `/doctor/chats/{id}`.
String chatThreadPath(String basePath, String chatId) => '$basePath/chats/$chatId';

// ---- D16 / AS9 / P11 inbox ----------------------------------------------------------------------

class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key, required this.basePath, this.openSingle = false});

  /// `/doctor`, `/assistant` or `/patient`.
  final String basePath;

  /// Patients with one doctor go straight to the thread (P11 is shown only with several doctors).
  final bool openSingle;

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  final _search = TextEditingController();
  bool _redirected = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inbox = ref.watch(chatInboxProvider);
    final staff = widget.basePath != '/patient';

    if (widget.openSingle && !_redirected && inbox.value?.length == 1) {
      _redirected = true;
      final id = inbox.value!.single.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push(chatThreadPath(widget.basePath, id));
      });
    }

    return Column(
      children: [
        if (staff)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ContentWidth(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => ref.read(chatInboxProvider.notifier).search(v),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchChats, isDense: true),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(chatInboxProvider.future),
            child: AsyncValueView(
              value: inbox,
              onRetry: () => ref.invalidate(chatInboxProvider),
              data: (chats) => chats.isEmpty
                  ? ListView(children: [EmptyState(icon: Icons.chat_bubble_outline, message: l10n.noChats)])
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: chats.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) => ContentWidth(
                        child: _ChatRow(chat: chats[index], onTap: () => context.push(chatThreadPath(widget.basePath, chats[index].id))),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.onTap});

  final ChatSummary chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preview = switch (chat.lastType) {
      'image' => l10n.chatImage,
      'file' => l10n.chatFile,
      _ => chat.lastText ?? l10n.chatNoMessages,
    };
    final unread = chat.unreadCount > 0;
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(
        [chat.displayName(arabic: context.isArabic), if (chat.fileNumber != null) l10n.fileNumber(chat.fileNumber!)].join(' · '),
        style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chat.lastAt != null) Text(context.date(chat.lastAt!), style: theme.textTheme.labelSmall),
          if (unread) ...[
            const SizedBox(height: 4),
            Badge(label: Text('${chat.unreadCount}')),
          ],
        ],
      ),
    );
  }
}

// ---- D17 / P12 thread ---------------------------------------------------------------------------

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId, required this.staff, this.canSaveToFile = false});

  final String chatId;
  final bool staff;

  /// Staff with `filesManage` (BR-C4).
  final bool canSaveToFile;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  ChatThreadController get _controller => ref.read(chatThreadProvider(widget.chatId).notifier);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(l10n, error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _errorText(AppLocalizations l10n, Object error) => switch (ApiError.from(error).code) {
        'CHAT_UNAVAILABLE' => l10n.chatDoctorUnavailable,
        'DOCTOR_SUSPENDED' => l10n.chatSuspended,
        'FILE_TOO_LARGE' => l10n.fileTooLarge,
        _ => l10n.apiErrorMessage(error),
      };

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await _controller.sendText(text);
      _text.clear();
    });
  }

  Future<void> _attach() async {
    final l10n = context.l10n;
    final mobile = ref.read(appPlatformProvider) == AppPlatform.mobile;
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mobile) ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l10n.chatCamera), onTap: () => Navigator.pop(context, 'camera')),
            if (mobile) ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l10n.chatGallery), onTap: () => Navigator.pop(context, 'gallery')),
            ListTile(leading: const Icon(Icons.attach_file), title: Text(l10n.chatFileOption), onTap: () => Navigator.pop(context, 'file')),
          ],
        ),
      ),
    );
    if (source == null) return;

    Uint8List? bytes;
    String? name;
    String mime = 'application/octet-stream';
    if (source == 'file') {
      final file = await FilePicker.pickFile();
      bytes = await file?.readAsBytes();
      name = file?.name;
      mime = _mimeFor(name ?? '');
    } else {
      final image = await ImagePicker().pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85, maxWidth: 2400);
      if (image != null) {
        bytes = await image.readAsBytes();
        name = image.name;
        mime = image.mimeType ?? 'image/jpeg';
      }
    }
    if (bytes == null || name == null) return;
    await _run(() => _controller.sendFile(bytes!, name!, mime));
  }

  static String _mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _attachmentActions(ChatMessage message) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.ios_share), title: Text(l10n.shareOrSave), onTap: () => Navigator.pop(context, 'share')),
            if (widget.canSaveToFile)
              ListTile(
                leading: const Icon(Icons.drive_folder_upload_outlined),
                title: Text(message.savedRecordId == null ? l10n.saveToPatientFile : l10n.savedToPatientFile),
                enabled: message.savedRecordId == null,
                onTap: () => Navigator.pop(context, 'save'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'share') {
      await _run(() async {
        final bytes = await ref.read(chatAttachmentProvider((widget.chatId, message.id)).future);
        await FileShare.share(bytes, fileName: message.fileName ?? 'file', mimeType: message.mimeType ?? 'application/octet-stream');
      });
    } else if (action == 'save') {
      final category = await showDialog<String>(context: context, builder: (context) => const _CategoryDialog());
      if (category == null) return;
      await _run(() => _controller.saveToFile(message, category));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.savedToPatientFile)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = ref.watch(chatThreadProvider(widget.chatId));
    final chat = thread.value?.chat;

    return Scaffold(
      appBar: AppBar(title: Text(chat?.displayName(arabic: context.isArabic) ?? '')),
      body: AsyncValueView(
        value: thread,
        onRetry: () => ref.invalidate(chatThreadProvider(widget.chatId)),
        data: (data) => Column(
          children: [
            Expanded(
              child: data.messages.isEmpty
                  ? EmptyState(icon: Icons.forum_outlined, message: l10n.chatStart)
                  : LoadMoreListener(
                      onEnd: _controller.loadOlder,
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: data.messages.length,
                        itemBuilder: (context, index) => ContentWidth(
                          child: _Bubble(
                            message: data.messages[index],
                            chatId: widget.chatId,
                            mine: widget.staff ? data.messages[index].senderRole != 'patient' : data.messages[index].senderRole == 'patient',
                            staffView: widget.staff,
                            onAttachment: () => _attachmentActions(data.messages[index]),
                          ),
                        ),
                      ),
                    ),
            ),
            if (!data.chat.canSend)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  data.chat.unavailableReason == 'DOCTOR_SUSPENDED' ? l10n.chatSuspended : l10n.chatDoctorUnavailable,
                  textAlign: TextAlign.center,
                ),
              )
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ContentWidth(
                    child: Row(
                      children: [
                        IconButton(tooltip: l10n.chatAttach, onPressed: _sending ? null : _attach, icon: const Icon(Icons.attach_file)),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 2000,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendText(),
                            decoration: InputDecoration(hintText: l10n.chatTypeMessage, counterText: '', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: l10n.chatSend,
                          onPressed: _sending ? null : _sendText,
                          icon: _sending
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.chatId, required this.mine, required this.staffView, required this.onAttachment});

  final ChatMessage message;
  final String chatId;
  final bool mine;
  final bool staffView;
  final VoidCallback onAttachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = mine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground = mine ? scheme.onPrimaryContainer : scheme.onSurface;

    // BR-C8: patients see assistant messages as «مساعد العيادة — name»; staff see every sender.
    String? sender;
    if (message.senderRole == 'assistant') {
      sender = staffView ? message.senderName : l10n.clinicAssistant(message.senderName);
    } else if (staffView && message.senderRole == 'doctor' && !mine) {
      sender = message.senderName;
    }

    Widget content;
    if (message.isImage) {
      final bytes = ref.watch(chatAttachmentProvider((chatId, message.id)));
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
          child: bytes.hasValue && bytes.value!.isNotEmpty
              ? Image.memory(bytes.value!, fit: BoxFit.cover, semanticLabel: message.fileName)
              : const SizedBox(width: 160, height: 120, child: Center(child: Icon(Icons.image_outlined))),
        ),
      );
    } else if (message.hasAttachment) {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.insert_drive_file_outlined, color: foreground),
        const SizedBox(width: 8),
        Flexible(child: Text(message.fileName ?? '', style: TextStyle(color: foreground, decoration: TextDecoration.underline))),
      ]);
    } else {
      content = SelectableText(message.text ?? '', style: TextStyle(color: foreground));
    }

    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GestureDetector(
          onTap: message.hasAttachment ? onAttachment : null,
          onLongPress: message.hasAttachment ? onAttachment : null,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sender != null) Text(sender, style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
                content,
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.dateTime(message.createdAt), style: theme.textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.7))),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(message.readAt != null ? Icons.done_all : Icons.done, size: 14,
                          color: message.readAt != null ? scheme.primary : foreground.withValues(alpha: 0.7),
                          semanticLabel: message.readAt != null ? l10n.chatRead : l10n.chatDelivered),
                    ],
                    if (message.savedRecordId != null && staffView) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.folder_outlined, size: 14, color: foreground.withValues(alpha: 0.7), semanticLabel: l10n.savedToPatientFile),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// BR-C4 asks for the category when saving an attachment.
class _CategoryDialog extends StatelessWidget {
  const _CategoryDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SimpleDialog(
      title: Text(l10n.chooseCategory),
      children: [
        for (final (code, label) in [
          ('prescription', l10n.fileCategoryPrescription),
          ('lab', l10n.fileCategoryLab),
          ('radiology', l10n.fileCategoryRadiology),
          ('other', l10n.fileCategoryOther),
        ])
          SimpleDialogOption(onPressed: () => Navigator.pop(context, code), child: Text(label)),
      ],
    );
  }
}
