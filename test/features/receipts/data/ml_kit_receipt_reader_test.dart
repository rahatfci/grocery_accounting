import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/receipts/data/ml_kit_receipt_reader.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_reader.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';

import '../fake_receipts.dart';

final _today = DateTime(2026, 9, 24);

void main() {
  late Directory scratch;
  late List<String> readPaths;
  late List<List<int>> readBytes;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('reader_test');
    readPaths = [];
    readBytes = [];
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  MlKitReceiptReader reader(
    List<OcrLine> Function() lines, {
    bool isWeb = false,
  }) => MlKitReceiptReader.withSeams(
    recognize: (path) async {
      readPaths.add(path);
      readBytes.add(File(path).readAsBytesSync());
      return lines();
    },
    scratchDirectory: () async => scratch,
    isWeb: isWeb,
  );

  test('recognises the photo from a scratch file and parses it', () async {
    final photo = testPhoto(7);

    final result = await reader(
      () => const [
        OcrLine(text: 'PANE 1,20', left: 0, top: 0, right: 90, bottom: 16),
        OcrLine(text: 'TOTALE 1,20', left: 0, top: 20, right: 90, bottom: 36),
      ],
    ).read(photo, today: _today);

    final reading = (result as Ok<ReceiptReading, ReceiptReadFailure>).value;
    expect(reading.total, 1.20);
    expect(reading.lines.single.rawText, 'PANE');
    expect(readBytes.single, photo.bytes);
  });

  test('deletes the scratch file after reading', () async {
    await reader(() => const []).read(testPhoto(), today: _today);

    expect(File(readPaths.single).existsSync(), isFalse);
    expect(scratch.listSync(), isEmpty);
  });

  test('a recogniser failure is a read failure, and cleans up', () async {
    final thrown = StateError('ml kit');

    final result = await reader(
      () => throw thrown,
    ).read(testPhoto(), today: _today);

    final failure = (result as Err<ReceiptReading, ReceiptReadFailure>).error;
    expect(failure.cause, thrown);
    expect(failure.message, 'Could not read the receipt. Fill it in by hand');
    expect(scratch.listSync(), isEmpty);
  });

  test('a scratch directory that cannot be used is a read failure', () async {
    final broken = MlKitReceiptReader.withSeams(
      recognize: (_) async => const [],
      scratchDirectory: () async => Directory('${scratch.path}/missing/deeper'),
      isWeb: false,
    );

    final result = await broken.read(testPhoto(), today: _today);

    expect(result, isA<Err<ReceiptReading, ReceiptReadFailure>>());
  });

  test('web reads nothing and never touches the recogniser', () async {
    final result = await reader(
      () => throw StateError('must not run'),
      isWeb: true,
    ).read(testPhoto(), today: _today);

    expect(
      (result as Ok<ReceiptReading, ReceiptReadFailure>).value.isEmpty,
      isTrue,
    );
    expect(readPaths, isEmpty);
  });
}
