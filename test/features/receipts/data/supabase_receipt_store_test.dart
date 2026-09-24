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
    Future<SupabaseReceiptStore> keptAndConfirmed(List<String> ids) async {
      final store = phone();
      for (final (index, id) in ids.indexed) {
        await store.keep(id, testPhoto(index));
        await store.confirm(id);
      }
      return store;
    }

    test('queues offline', () {
      expect(phone().queuesOffline, isTrue);
    });

    test('keep writes the photo aside, where flush does not see it', () async {
      final photo = testPhoto();
      final store = phone();

      final result = await store.keep('p1', photo);

      expect(result, isA<Ok<void, DataFailure>>());
      expect(queued(), ['p1.img.new']);
      expect(File('${queue.path}/p1.img.new').readAsBytesSync(), photo.bytes);
      expect(await store.flush(), 0);
      expect(uploads, isEmpty);
    });

    test('confirm hands the photo to the queue', () async {
      final store = phone();
      await store.keep('p1', testPhoto());

      expect(await store.confirm('p1'), isA<Ok<void, DataFailure>>());

      expect(queued(), ['p1.img']);
      expect(uploads, isEmpty);
    });

    test('confirming a photo that was never kept fails', () async {
      final result = await phone().confirm('p1');

      expect(result, isA<Err<void, DataFailure>>());
    });

    test('flush uploads to the purchase path and empties the queue', () async {
      final store = await keptAndConfirmed(['p1', 'p2']);

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
      final store = await keptAndConfirmed(['p1']);
      uploadResult = const Err(ConnectionUnavailable());

      expect(await store.flush(), 1);
      expect(queued(), ['p1.img']);

      uploadResult = const Ok(null);
      expect(await store.flush(), 0);
      expect(queued(), isEmpty);
    });

    test('discard removes an unconfirmed photo, and tolerates a missing '
        'one', () async {
      final store = phone();
      await store.keep('p1', testPhoto());

      await store.discard('p1');
      await store.discard('p1');

      expect(queued(), isEmpty);
      await store.flush();
      expect(uploads, isEmpty);
    });

    test(
      'a flush already running never uploads a photo kept during it',
      () async {
        final store = await keptAndConfirmed(['p1']);
        uploadGate = Completer<void>();

        final running = store.flush();
        await pumpEventQueue();
        // A second purchase keeps its photo while the first upload is in
        // flight, and is then refused.
        await store.keep('p2', testPhoto(2));
        uploadGate?.complete();
        await running;
        await store.discard('p2');

        expect(uploads.map((u) => u.path), ['receipts/p1']);
        expect(queued(), isEmpty);
      },
    );

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
      final store = await keptAndConfirmed(['p1']);
      uploadGate = Completer<void>();

      final first = store.flush();
      await pumpEventQueue();
      final second = await store.flush();
      uploadGate?.complete();
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

    test('does not queue offline', () {
      expect(web().queuesOffline, isFalse);
    });

    test('keep uploads nothing and never touches the disk', () async {
      final result = await web().keep('p1', testPhoto());

      expect(result, isA<Ok<void, DataFailure>>());
      expect(uploads, isEmpty);
      expect(queue.existsSync(), isFalse);
    });

    test('confirm uploads the kept photo to the purchase path', () async {
      final store = web();
      final photo = testPhoto(4);
      await store.keep('p1', photo);

      final result = await store.confirm('p1');

      expect(result, isA<Ok<void, DataFailure>>());
      expect(uploads.single.path, 'receipts/p1');
      expect(uploads.single.bytes, photo.bytes);
    });

    test('a failed upload is returned as its mapped failure', () async {
      final store = web();
      await store.keep('p1', testPhoto());
      uploadResult = const Err(ConnectionUnavailable());

      final result = await store.confirm('p1');

      expect(
        (result as Err<void, DataFailure>).error,
        const ConnectionUnavailable(),
      );
    });

    test('discard drops the photo, so nothing is ever uploaded', () async {
      final store = web();
      await store.keep('p1', testPhoto());

      await store.discard('p1');

      expect(await store.confirm('p1'), isA<Err<void, DataFailure>>());
      expect(await store.flush(), 0);
      expect(uploads, isEmpty);
    });
  });
}
