import 'dart:async';

import 'package:grocery_accounting/features/reports/data/csv_sharer.dart';

class FakeCsvSharer implements CsvSharer {
  final shared = <({String fileName, String csv})>[];

  CsvShareOutcome outcome = const CsvShared();

  /// When set, a share waits on this, so a test can observe the progress.
  Completer<void>? gate;

  @override
  Future<CsvShareOutcome> share({
    required String fileName,
    required String csv,
  }) async {
    shared.add((fileName: fileName, csv: csv));
    await gate?.future;
    return outcome;
  }
}
