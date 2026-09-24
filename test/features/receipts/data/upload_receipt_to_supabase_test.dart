import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/core/supabase_config.dart';
import 'package:grocery_accounting/features/receipts/data/supabase_receipt_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]);

Future<Result<void, DataFailure>> _upload(MockClient client) =>
    uploadReceiptToSupabase(client, 'receipts/p1', _bytes, 'image/jpeg');

DataFailure _error(Result<void, DataFailure> result) =>
    (result as Err<void, DataFailure>).error;

void main() {
  test('posts the bytes to the bucket path with the publishable key', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response('{"Key":"x"}', 200);
    });

    final result = await _upload(client);

    expect(result, isA<Ok<void, DataFailure>>());
    expect(sent.method, 'POST');
    expect(
      sent.url.toString(),
      '${SupabaseConfig.url}/storage/v1/object/Grocery%20Accounting/receipts/p1',
    );
    expect(sent.headers['apikey'], SupabaseConfig.publishableKey);
    expect(
      sent.headers['Authorization'],
      'Bearer ${SupabaseConfig.publishableKey}',
    );
    expect(sent.headers['Content-Type'], 'image/jpeg');
    expect(sent.headers.containsKey('x-upsert'), isFalse);
    expect(sent.bodyBytes, _bytes);
  });

  test('an object already there counts as stored', () async {
    for (final response in [
      http.Response('{"error":"Duplicate"}', 409),
      http.Response('{"statusCode":"409","error":"Duplicate"}', 400),
      http.Response('{"statusCode":409,"error":"Duplicate"}', 400),
    ]) {
      final result = await _upload(MockClient((_) async => response));

      expect(result, isA<Ok<void, DataFailure>>());
    }
  });

  test('a refusal Storage sends as 400 is read from its body', () async {
    // What the bucket returns when no policy allows the upload.
    final result = await _upload(
      MockClient(
        (_) async => http.Response(
          '{"statusCode":"403","error":"Unauthorized",'
          '"message":"new row violates row-level security policy"}',
          400,
        ),
      ),
    );

    expect(_error(result), const PermissionDenied());
  });

  test('a 400 without a usable body stays unexpected', () async {
    for (final body in ['not json', '{"error":"x"}', '[1]']) {
      final result = await _upload(
        MockClient((_) async => http.Response(body, 400)),
      );

      expect(_error(result), const UnexpectedDataFailure());
    }
  });

  test('a refused upload is permission denied', () async {
    for (final status in [401, 403]) {
      final result = await _upload(
        MockClient((_) async => http.Response('{}', status)),
      );

      expect(_error(result), const PermissionDenied());
    }
  });

  test('any other status is unexpected', () async {
    for (final status in [400, 404, 500]) {
      final result = await _upload(
        MockClient((_) async => http.Response('{"error":"nope"}', status)),
      );

      expect(_error(result), const UnexpectedDataFailure());
    }
  });

  test('no network is connection unavailable', () async {
    final result = await _upload(
      MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(_error(result), const ConnectionUnavailable());
  });

  // testWidgets runs in a fake clock, so the 30 second timeout elapses
  // without the test waiting for it.
  testWidgets('an upload that never answers times out as unavailable', (
    tester,
  ) async {
    Result<void, DataFailure>? result;
    unawaited(
      _upload(
        MockClient((_) => Completer<http.Response>().future),
      ).then((value) => result = value),
    );

    await tester.pump(const Duration(seconds: 29));
    expect(result, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(
      (result as Err<void, DataFailure>).error,
      const ConnectionUnavailable(),
    );
  });
}
