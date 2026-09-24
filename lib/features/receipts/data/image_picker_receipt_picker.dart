import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

import '../../../core/result.dart';
import '../logic/receipt.dart';
import 'receipt_picker.dart';

/// The codes both platform implementations use for a refused permission.
const _accessDenied = {'camera_access_denied', 'photo_access_denied'};

@LazySingleton(as: ReceiptPicker)
class ImagePickerReceiptPicker implements ReceiptPicker {
  const ImagePickerReceiptPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<Result<ReceiptPhoto?, ReceiptPickFailure>> pick(
    ReceiptSource source,
  ) async {
    try {
      final file = await _picker.pickImage(
        source: switch (source) {
          ReceiptSource.camera => ImageSource.camera,
          ReceiptSource.gallery => ImageSource.gallery,
        },
        // Small enough to upload over shop signal, large enough that feature
        // 10 can still read the print. Re-encoding also turns HEIC into JPEG.
        maxWidth: 2000,
        imageQuality: 85,
        // Full metadata would need the photo library permission on iOS for
        // nothing the app uses.
        requestFullMetadata: false,
      );
      if (file == null) {
        return const Ok(null);
      }
      return Ok(ReceiptPhoto(await file.readAsBytes()));
    } on PlatformException catch (error, stackTrace) {
      return Err(
        _accessDenied.contains(error.code)
            ? const ReceiptAccessDenied()
            : ReceiptPickerUnavailable(error, stackTrace),
      );
    } catch (error, stackTrace) {
      return Err(ReceiptPickerUnavailable(error, stackTrace));
    }
  }
}
