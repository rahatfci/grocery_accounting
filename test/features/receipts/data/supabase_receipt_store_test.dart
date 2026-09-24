import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/receipts/data/supabase_receipt_store.dart';

import '../fake_receipts.dart';

void main() {
  late Directory root;
  late Directory queue;
  late List<({String path, Uint8List bytes, String contentType})> uploads;
  Result<void, DataFailure> uploadResult = const Ok(null);
  Completer<void>? uploadGate;

  Future<Result<void, DataFailure>> upload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    uploads.add((path: path, bytes: bytes, contentType: contentType));
    await uploadGate?.future;
    return uploadResult;
  }

  SupabaseReceiptStore phone() => SupabaseReceiptStore.withSeams(
    upload: upload,
    queueDirectory: () async => queue,
    isWeb: false,
  );

  List<String> queued() => queue.existsSync()
      ? (queue.listSync().map((e) => e.uri.pathSegments.last).toList()..sort())
      : const [];

  setUp(() {
    root = Directory.systemTemp.createTempSync('receipts_test');
    queue = Directory('${root.path}/pending_receipts');
    uploads = [];
    uploadResult = const Ok(null);
    uploadGate = null;
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('on a phone', () {
    test('keep writes the photo to the queue and uploads nothing', () async {
      final photo = testPhoto();

      final result = await phone().keep('p1', photo);

      expect(result, isA<Ok<void, DataFailure>>());
      expect(queued(), ['p1.img']);
      expect(File('${queue.path}/p1.img').readAsBytesSync(), photo.bytes);
      expect(uploads, isEmpty);
    });

    test('flush uploads to the purchase path and empties the queue', () async {
      final store = phone();
      await store.keep('p1', testPhoto(1));
      await store.keep('p2', testPhoto(2));

      final remaining = await store.flush();

      expect(remaining, 0);
      expect(queued(), isEmpty);
      expect(uploads.map((u) => u.path).toSet(), {
        'receipts/p1',
        'receipts/p2',
      });
      expect(uploads.first.contentType, 'image/jpeg');
    });

    test('a failed upload stays queued for the next flush', () async {
      final store = phone();
      await store.keep('p1', testPhoto());
      uploadResult = const Err(ConnectionUnavailable());

      expect(await store.flush(), 1);
      expect(queued(), ['p1.img']);

      uploadResult = const Ok(null);
      expect(await store.flush(), 0);
      expect(queued(), isEmpty);
    });

    test('discard removes a kept photo, and tolerates a missing one', () async {
      final store = phone();
      await store.keep('p1', testPhoto());

      await store.discard('p1');
      await store.discard('p1');

      expect(queued(), isEmpty);
      await store.flush();
      expect(uploads, isEmpty);
    });

    test('flush ignores files the queue did not write', () async {
      final store = phone();
      queue.createSync(recursive: true);
      File('${queue.path}/.DS_Store').writeAsStringSync('x');
      File('${queue.path}/.p9.img.partial').writeAsStringSync('x');

      expect(await store.flush(), 0);
      expect(uploads, isEmpty);
    });

    test('flush with no queue directory does nothing', () async {
      expect(await phone().flush(), 0);
    });

    test('a second flush while one runs does nothing', () async {
      final store = phone();
      await store.keep('p1', testPhoto());
      uploadGate = Completer<void>();

      final first = store.flush();
      await pumpEventQueue();
      final second = await store.flush();
      uploadGate!.complete();
      await first;

      expect(second, 0);
      expect(uploads, hasLength(1));
      expect(queued(), isEmpty);
    });
  });

  group('on web', () {
    SupabaseReceiptStore web() => SupabaseReceiptStore.withSeams(
      upload: upload,
      queueDirectory: () async => throw StateError('web has no disk'),
      isWeb: true,
    );

    test('keep uploads straight away and never touches the disk', () async {
      final result = await web().keep('p1', testPhoto());

      expect(result, isA<Ok<void, DataFailure>>());
      expect(uploads.single.path, 'receipts/p1');
      expect(queue.existsSync(), isFalse);
    });

    test('a failed upload is returned as its mapped failure', () async {
      uploadResult = const Err(ConnectionUnavailable());

      final result = await web().keep('p1', testPhoto());

      expect(
        (result as Err<void, DataFailure>).error,
        const ConnectionUnavailable(),
      );
    });

    test('discard and flush do nothing', () async {
      final store = web();

      await store.discard('p1');

      expect(await store.flush(), 0);
      expect(uploads, isEmpty);
    });
  });
}
