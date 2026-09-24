import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:share_plus/share_plus.dart';

import 'csv_sharer.dart';

@LazySingleton(as: CsvSharer)
class SharePlusCsvSharer implements CsvSharer {
  @factoryMethod
  SharePlusCsvSharer() : this.withSeam(SharePlus.instance.share);

  /// The plugin call replaced, so the file handed over can be inspected.
  @visibleForTesting
  SharePlusCsvSharer.withSeam(this._share);

  final Future<ShareResult> Function(ShareParams params) _share;

  @override
  Future<CsvShareOutcome> share({
    required String fileName,
    required String csv,
  }) async {
    try {
      final result = await _share(
        ShareParams(
          files: [XFile.fromData(csvFileBytes(csv), mimeType: 'text/csv')],
          fileNameOverrides: [fileName],
          subject: fileName,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.dismissed => const CsvShareDismissed(),
        // `unavailable` is a platform that cannot say what happened, such as a
        // web download, which has already been handed over.
        ShareResultStatus.success ||
        ShareResultStatus.unavailable => const CsvShared(),
      };
    } catch (error, stackTrace) {
      return CsvShareFailed(error, stackTrace);
    }
  }
}
