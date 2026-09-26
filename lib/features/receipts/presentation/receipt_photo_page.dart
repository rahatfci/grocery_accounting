import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/notes.dart';

/// A receipt photo at full size, to pinch and zoom.
class ReceiptPhotoPage extends StatelessWidget {
  const ReceiptPhotoPage({required this.bytes, this.onRemove, super.key});

  final Uint8List bytes;

  /// Offered while the photo can still change, on a purchase being reviewed.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final onRemove = this.onRemove;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Receipt photo',
        leading: TopBarLeading.close,
        actions: [
          if (onRemove != null)
            IconButton(
              icon: const Icon(Symbols.delete_rounded),
              tooltip: 'Remove photo',
              onPressed: () {
                Navigator.of(context).pop();
                onRemove();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              semanticLabel: 'Receipt photo',
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const NoteRow(
                icon: Symbols.broken_image_rounded,
                text: 'This photo cannot be shown.',
                iconColor: AppColors.iconSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
