import 'package:flutter/material.dart';

import '../data_failure.dart';
import '../refusal_window.dart';
import '../result.dart';

/// Shows a refused write. A write still pending when the window closes is
/// queued offline, and the stream already shows it, so it says nothing.
Future<void> reportRefusal(
  ScaffoldMessengerState messenger,
  Future<Result<void, DataFailure>> write,
) async {
  final result = await write.timeout(
    refusalWindow,
    onTimeout: () => const Ok(null),
  );
  if (result case Err(:final error)) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}
