import 'package:flutter/material.dart';

import '../data/receipt_picker.dart';

/// Asks whether to take a photo or choose one. Null when dismissed.
Future<ReceiptSource?> showReceiptSourceSheet(BuildContext context) =>
    showModalBottomSheet<ReceiptSource>(
      context: context,
      builder: (_) => const ReceiptSourceSheet(),
    );

class ReceiptSourceSheet extends StatelessWidget {
  const ReceiptSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.of(context).pop(ReceiptSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ReceiptSource.gallery),
          ),
        ],
      ),
    );
  }
}
