import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/reports/data/csv_sharer.dart';
import 'package:grocery_accounting/features/reports/data/share_plus_csv_sharer.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('file bytes are UTF-8 behind a byte order mark', () {
    final bytes = csvFileBytes('Città;1,50\r\n');

    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(bytes.sublist(3), [
      ...'Citt'.codeUnits,
      0xC3,
      0xA0,
      ...';1,50\r\n'.codeUnits,
    ]);
  });

  test('hands the platform one named CSV file', () async {
    late ShareParams sent;
    final sharer = SharePlusCsvSharer.withSeam((params) async {
      sent = params;
      return const ShareResult('ok', ShareResultStatus.success);
    });

    final outcome = await sharer.share(
      fileName: 'grocery-2026-09.csv',
      csv: 'Date\r\n',
    );

    expect(outcome, isA<CsvShared>());
    expect(sent.fileNameOverrides, ['grocery-2026-09.csv']);
    final files = sent.files ?? const [];
    expect(files, hasLength(1));
    expect(files.single.mimeType, 'text/csv');
    expect(await files.single.readAsBytes(), csvFileBytes('Date\r\n'));
  });

  test('maps dismissed, unavailable and a thrown error', () async {
    Future<CsvShareOutcome> shareWith(
      Future<ShareResult> Function(ShareParams) seam,
    ) => SharePlusCsvSharer.withSeam(seam).share(fileName: 'f.csv', csv: '');

    expect(
      await shareWith(
        (_) async => const ShareResult('', ShareResultStatus.dismissed),
      ),
      isA<CsvShareDismissed>(),
    );
    expect(
      await shareWith(
        (_) async => const ShareResult('', ShareResultStatus.unavailable),
      ),
      isA<CsvShared>(),
    );
    final failed = await shareWith((_) async => throw StateError('plugin'));
    expect(failed, isA<CsvShareFailed>());
    expect((failed as CsvShareFailed).cause, isA<StateError>());
  });
}
