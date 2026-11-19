import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/platform/file_share.dart';
import '../application/patient_providers.dart';
import 'patient_format.dart';
import 'widgets/patient_widgets.dart';

/// P7 "View PDF": the stored PDF, exactly as the doctor sent it (BR-RX4). Always on a white
/// page whatever the theme, like the paper copy.
class PdfViewScreen extends ConsumerWidget {
  const PdfViewScreen({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = FileRef.prescriptionPdf(prescriptionId);
    final bytes = ref.watch(fileBytesProvider(file));
    final fileName = 'el3yada-$prescriptionId.pdf';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.viewPdf),
        actions: [
          if (bytes.hasValue)
            IconButton(
              tooltip: context.l10n.shareOrSave,
              icon: const Icon(Icons.ios_share),
              onPressed: () => FileShare.share(bytes.value!, fileName: fileName, mimeType: 'application/pdf'),
            ),
        ],
      ),
      body: AsyncValueView(
        value: bytes,
        onRetry: () => ref.invalidate(fileBytesProvider(file)),
        data: (data) => PdfViewer.data(data, sourceName: fileName),
      ),
    );
  }
}
