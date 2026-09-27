import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A mapped failure message, announced by a screen reader when it appears.
///
/// Only ever given text that already came from an `AuthFailure` or a
/// `DataFailure`, so a raw Firebase code cannot reach it.
class FailureMessage extends StatelessWidget {
  const FailureMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          color: AppColors.negativeSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(
              Symbols.error_rounded,
              size: 20,
              color: AppColors.negative,
            ),
            const SizedBox(width: AppSpace.s10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.negativeStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A whole screen or section that failed to load, with the way back.
class LoadFailure extends StatelessWidget {
  const LoadFailure({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FailureMessage(message: message),
              const SizedBox(height: AppSpace.s16),
              Center(
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
