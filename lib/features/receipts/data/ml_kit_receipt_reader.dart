import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/result.dart';
import '../logic/receipt.dart';
import '../logic/receipt_reading.dart';
import 'receipt_reader.dart';

/// Recognises the text lines in the image file at a path.
typedef RecognizeLines = Future<List<OcrLine>> Function(String path);

@LazySingleton(as: ReceiptReader)
class MlKitReceiptReader implements ReceiptReader {
  @factoryMethod
  MlKitReceiptReader(TextRecognizer recognizer)
    : this.withSeams(
        recognize: (path) async {
          final recognized = await recognizer.processImage(
            InputImage.fromFilePath(path),
          );
          return [
            for (final block in recognized.blocks)
              for (final line in block.lines)
                OcrLine(
                  text: line.text,
                  left: line.boundingBox.left,
                  top: line.boundingBox.top,
                  right: line.boundingBox.right,
                  bottom: line.boundingBox.bottom,
                ),
          ];
        },
        scratchDirectory: getTemporaryDirectory,
        isWeb: kIsWeb,
      );

  /// The plugin and path lookups replaced, so reading can be tested without
  /// ML Kit.
  @visibleForTesting
  MlKitReceiptReader.withSeams({
    required this._recognize,
    required this._scratchDirectory,
    required this._isWeb,
  });

  final RecognizeLines _recognize;
  final Future<Directory> Function() _scratchDirectory;
  final bool _isWeb;

  @override
  Future<Result<ReceiptReading, ReceiptReadFailure>> read(
    ReceiptPhoto photo, {
    required DateTime today,
  }) async {
    // ML Kit has no web build, so web keeps manual entry.
    if (_isWeb) {
      return const Ok(ReceiptReading.empty);
    }
    File? scratch;
    try {
      // ML Kit reads an encoded JPEG only from a file path.
      final directory = await _scratchDirectory();
      scratch = File(
        '${directory.path}/receipt_read_${DateTime.now().microsecondsSinceEpoch}',
      );
      await scratch.writeAsBytes(photo.bytes, flush: true);
      final lines = await _recognize(scratch.path);
      return Ok(parseReceipt(lines, today: today));
    } catch (error, stackTrace) {
      return Err(ReceiptReadFailure(error, stackTrace));
    } finally {
      try {
        await scratch?.delete();
      } on FileSystemException {
        // Never written, or already gone.
      }
    }
  }
}
