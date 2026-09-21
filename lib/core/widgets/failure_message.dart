import 'package:flutter/material.dart';

/// A mapped failure message, announced by a screen reader when it appears.
///
/// Only ever given text that already came from an `AuthFailure` or a
/// `DataFailure`, so a raw Firebase code cannot reach it.
class FailureMessage extends StatelessWidget {
  const FailureMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
