import 'dart:typed_data';

/// A receipt image picked on this device and not yet stored anywhere.
///
/// Deliberately not `Equatable`: it rides along in the purchase draft, and
/// comparing megabytes of bytes on every keystroke would be wasted work.
/// Identity is the right equality for a photo that was picked once.
final class ReceiptPhoto {
  const ReceiptPhoto(this.bytes);

  final Uint8List bytes;
}

const _pendingSuffix = '.img';
final _purchaseId = RegExp(r'^[A-Za-z0-9]+$');

/// Where the receipt for [purchaseId] lives in Storage.
///
/// One object per purchase, so an upload that is retried overwrites itself
/// rather than piling up copies.
String receiptStoragePath(String purchaseId) => 'receipts/$purchaseId';

/// The name a queued receipt is kept under on the device.
String pendingReceiptName(String purchaseId) => '$purchaseId$_pendingSuffix';

/// The purchase a queued file belongs to, or null for any file the queue did
/// not write, so a stray file is never uploaded.
String? purchaseIdFromPendingName(String fileName) {
  if (!fileName.endsWith(_pendingSuffix)) {
    return null;
  }
  final id = fileName.substring(0, fileName.length - _pendingSuffix.length);
  return _purchaseId.hasMatch(id) ? id : null;
}

/// The content type for [bytes], sniffed from the leading bytes because the
/// picker does not reliably report one.
String receiptContentType(Uint8List bytes) {
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) {
    return 'image/png';
  }
  // ISO base media: `ftyp` at offset 4, then a HEIF brand.
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
      const {
        'heic',
        'heix',
        'mif1',
        'msf1',
      }.contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
    return 'image/heic';
  }
  return 'application/octet-stream';
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) {
      return false;
    }
  }
  return true;
}
