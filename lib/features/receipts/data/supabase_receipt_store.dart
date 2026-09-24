import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../../core/supabase_config.dart';
import '../logic/receipt.dart';
import 'receipt_store.dart';

/// Stores [bytes] at [path] in the receipts bucket.
typedef ReceiptUpload =
    Future<Result<void, DataFailure>> Function(
      String path,
      Uint8List bytes,
      String contentType,
    );

/// Long enough for a 500 KB photo on poor signal. Past it the upload counts
/// as failed and the phone queue retries on the next flush; on web it bounds
/// how long saving waits.
const _uploadTimeout = Duration(seconds: 30);

/// Uploads one receipt through the Supabase Storage REST API.
///
/// Never overwrites: one purchase has one photo, so an object already at
/// [path] is that same photo from an earlier attempt whose reply was lost, and
/// it counts as stored. Not needing overwrite also means the bucket needs no
/// update policy.
@visibleForTesting
Future<Result<void, DataFailure>> uploadReceiptToSupabase(
  http.Client client,
  String path,
  Uint8List bytes,
  String contentType,
) async {
  final uri = Uri.parse(SupabaseConfig.url).replace(
    pathSegments: [
      'storage',
      'v1',
      'object',
      SupabaseConfig.receiptsBucket,
      ...path.split('/'),
    ],
  );
  try {
    final response = await client
        .post(
          uri,
          headers: {
            'apikey': SupabaseConfig.publishableKey,
            'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
            'Content-Type': contentType,
          },
          body: bytes,
        )
        .timeout(_uploadTimeout);
    return switch (_storageStatus(response)) {
      >= 200 && < 300 => const Ok(null),
      409 => const Ok(null),
      401 || 403 => const Err(PermissionDenied()),
      _ => const Err(UnexpectedDataFailure()),
    };
  } on TimeoutException {
    return const Err(ConnectionUnavailable());
  } on http.ClientException {
    return const Err(ConnectionUnavailable());
  } on SocketException {
    return const Err(ConnectionUnavailable());
  }
}

/// The status Storage meant. It answers some refusals with HTTP 400 and the
/// real status in the body, for example a missing bucket policy arrives as 400
/// with `"statusCode":"403"`, and an existing object as 400 with `"409"`.
int _storageStatus(http.Response response) {
  if (response.statusCode != 400) {
    return response.statusCode;
  }
  try {
    final body = jsonDecode(response.body);
    if (body is Map<String, Object?>) {
      final status = body['statusCode'];
      final parsed = switch (status) {
        final int value => value,
        final String value => int.tryParse(value),
        _ => null,
      };
      if (parsed != null) {
        return parsed;
      }
    }
  } on FormatException {
    // Not JSON, so the HTTP status is all there is.
  }
  return response.statusCode;
}

@LazySingleton(as: ReceiptStore)
class SupabaseReceiptStore implements ReceiptStore {
  @factoryMethod
  SupabaseReceiptStore(http.Client client)
    : this.withSeams(
        upload: (path, bytes, contentType) =>
            uploadReceiptToSupabase(client, path, bytes, contentType),
        queueDirectory: () async => Directory(
          '${(await getApplicationSupportDirectory()).path}/pending_receipts',
        ),
        isWeb: kIsWeb,
      );

  /// The network and path lookups replaced, so the queue can be tested
  /// against a real temporary directory.
  @visibleForTesting
  SupabaseReceiptStore.withSeams({
    required this._upload,
    required this._queueDirectory,
    required this._isWeb,
  });

  final ReceiptUpload _upload;
  final Future<Directory> Function() _queueDirectory;
  final bool _isWeb;

  bool _flushing = false;

  /// Web keeps a photo in memory until its purchase is accepted: there is
  /// nowhere durable to put it, and uploading first would orphan it on a
  /// refusal.
  final _held = <String, Uint8List>{};

  @override
  bool get queuesOffline => !_isWeb;

  @override
  Future<Result<void, DataFailure>> keep(
    String purchaseId,
    ReceiptPhoto photo,
  ) async {
    if (_isWeb) {
      _held[purchaseId] = photo.bytes;
      return const Ok(null);
    }
    try {
      final directory = await _queueDirectory();
      await directory.create(recursive: true);
      // Written aside and renamed, so nothing ever sees half a file. The name
      // it lands on is still one `flush` ignores, until `confirm`.
      final partial = File(
        '${directory.path}/.${pendingReceiptName(purchaseId)}.partial',
      );
      await partial.writeAsBytes(photo.bytes, flush: true);
      await partial.rename(_unconfirmed(directory, purchaseId).path);
      return const Ok(null);
    } on FileSystemException {
      return const Err(UnexpectedDataFailure());
    }
  }

  @override
  Future<Result<void, DataFailure>> confirm(String purchaseId) async {
    if (_isWeb) {
      final bytes = _held.remove(purchaseId);
      if (bytes == null) {
        return const Err(UnexpectedDataFailure());
      }
      return _uploadNow(purchaseId, bytes);
    }
    try {
      final directory = await _queueDirectory();
      await _unconfirmed(
        directory,
        purchaseId,
      ).rename('${directory.path}/${pendingReceiptName(purchaseId)}');
      return const Ok(null);
    } on FileSystemException {
      return const Err(UnexpectedDataFailure());
    }
  }

  @override
  Future<void> discard(String purchaseId) async {
    if (_isWeb) {
      _held.remove(purchaseId);
      return;
    }
    final directory = await _queueDirectory();
    try {
      await _unconfirmed(directory, purchaseId).delete();
    } on FileSystemException {
      // Already gone, which is the outcome wanted.
    }
  }

  File _unconfirmed(Directory directory, String purchaseId) =>
      File('${directory.path}/${pendingReceiptName(purchaseId)}.new');

  @override
  Future<int> flush() async {
    if (_isWeb || _flushing) {
      return 0;
    }
    _flushing = true;
    try {
      final directory = await _queueDirectory();
      if (!await directory.exists()) {
        return 0;
      }
      var remaining = 0;
      await for (final entry in directory.list()) {
        final purchaseId = purchaseIdFromPendingName(
          entry.uri.pathSegments.last,
        );
        if (entry is! File || purchaseId == null) {
          continue;
        }
        final uploaded = await _uploadNow(
          purchaseId,
          await entry.readAsBytes(),
        );
        if (uploaded is Ok) {
          await entry.delete();
        } else {
          remaining++;
        }
      }
      return remaining;
    } finally {
      _flushing = false;
    }
  }

  Future<Result<void, DataFailure>> _uploadNow(
    String purchaseId,
    Uint8List bytes,
  ) =>
      _upload(receiptStoragePath(purchaseId), bytes, receiptContentType(bytes));
}
