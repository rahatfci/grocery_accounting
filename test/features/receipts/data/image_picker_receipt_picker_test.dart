import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/receipts/data/image_picker_receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt.dart';
import 'package:image_picker/image_picker.dart';

class _FakeImagePicker extends ImagePicker {
  XFile? file;
  Object? thrown;
  final calls =
      <({ImageSource source, double? maxWidth, int? quality, bool metadata})>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add((
      source: source,
      maxWidth: maxWidth,
      quality: imageQuality,
      metadata: requestFullMetadata,
    ));
    final error = thrown;
    if (error != null) {
      throw error;
    }
    return file;
  }
}

void main() {
  late _FakeImagePicker images;
  late ImagePickerReceiptPicker picker;

  setUp(() {
    images = _FakeImagePicker();
    picker = ImagePickerReceiptPicker(images);
  });

  test('returns the picked bytes, sized for upload and reading', () async {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 7]);
    images.file = XFile.fromData(bytes);

    final result = await picker.pick(ReceiptSource.camera);

    final photo = (result as Ok<ReceiptPhoto?, ReceiptPickFailure>).value;
    expect(photo?.bytes, bytes);
    expect(images.calls.single.source, ImageSource.camera);
    expect(images.calls.single.maxWidth, 2000);
    expect(images.calls.single.quality, 85);
    expect(images.calls.single.metadata, isFalse);
  });

  test('picks from the gallery when asked', () async {
    await picker.pick(ReceiptSource.gallery);

    expect(images.calls.single.source, ImageSource.gallery);
  });

  test('a cancel is Ok with no photo', () async {
    final result = await picker.pick(ReceiptSource.gallery);

    expect((result as Ok<ReceiptPhoto?, ReceiptPickFailure>).value, isNull);
  });

  test('a refused permission is access denied, on either code', () async {
    for (final code in ['camera_access_denied', 'photo_access_denied']) {
      images.thrown = PlatformException(code: code);

      final result = await picker.pick(ReceiptSource.camera);

      expect(
        (result as Err<ReceiptPhoto?, ReceiptPickFailure>).error,
        const ReceiptAccessDenied(),
      );
    }
  });

  test('any other failure is unavailable and keeps its cause', () async {
    final platform = PlatformException(code: 'no_available_camera');
    images.thrown = platform;

    final result = await picker.pick(ReceiptSource.camera);

    final failure = (result as Err<ReceiptPhoto?, ReceiptPickFailure>).error;
    expect(failure, isA<ReceiptPickerUnavailable>());
    expect((failure as ReceiptPickerUnavailable).cause, platform);
    expect(failure.message, 'Could not open the camera or gallery');
  });

  test('a non-platform error is unavailable too', () async {
    images.thrown = StateError('boom');

    final result = await picker.pick(ReceiptSource.camera);

    expect(
      (result as Err<ReceiptPhoto?, ReceiptPickFailure>).error,
      isA<ReceiptPickerUnavailable>(),
    );
  });
}
