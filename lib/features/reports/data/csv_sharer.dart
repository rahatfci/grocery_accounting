import 'dart:convert';
import 'dart:typed_data';

/// What handing the export to the system did.
sealed class CsvShareOutcome {
  const CsvShareOutcome();
}

final class CsvShared extends CsvShareOutcome {
  const CsvShared();
}

/// The member closed the share sheet. Not an error.
final class CsvShareDismissed extends CsvShareOutcome {
  const CsvShareDismissed();
}

final class CsvShareFailed extends CsvShareOutcome {
  const CsvShareFailed(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;
}

/// Hands a CSV file to the platform: the share sheet on a phone, a download
/// on web.
abstract interface class CsvSharer {
  Future<CsvShareOutcome> share({
    required String fileName,
    required String csv,
  });
}

/// [csv] as file bytes: UTF-8 behind a byte order mark, which is what makes
/// Excel read accented shop and product names correctly on double-click.
Uint8List csvFileBytes(String csv) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
