import 'package:equatable/equatable.dart';

import '../../../core/result.dart';
import '../logic/receipt.dart';
import '../logic/receipt_reading.dart';

/// Why a photo could not be read. [cause] and [stackTrace] are kept so the
/// caller can report them; the member only sees [message].
final class ReceiptReadFailure extends Equatable {
  const ReceiptReadFailure(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;

  String get message => 'Could not read the receipt. Fill it in by hand';

  @override
  List<Object?> get props => [cause];
}

/// Reads a receipt photo on the device.
///
/// Implementations own every plugin type; none of them cross this boundary.
abstract interface class ReceiptReader {
  /// What could be read, which may be empty. [today] bounds the date, so a
  /// misread digit cannot put the purchase in the future.
  Future<Result<ReceiptReading, ReceiptReadFailure>> read(
    ReceiptPhoto photo, {
    required DateTime today,
  });
}
