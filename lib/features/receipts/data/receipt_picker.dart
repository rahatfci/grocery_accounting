import 'package:equatable/equatable.dart';

import '../../../core/result.dart';
import '../logic/receipt.dart';

enum ReceiptSource { camera, gallery }

/// Why a receipt could not be picked, already carrying the text to show.
sealed class ReceiptPickFailure extends Equatable {
  const ReceiptPickFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class ReceiptAccessDenied extends ReceiptPickFailure {
  const ReceiptAccessDenied()
    : super(
        'Camera or photo access is off. Allow it in Settings to add receipts',
      );
}

/// Anything else. [cause] and [stackTrace] are kept so the caller can report
/// them; they are never shown.
final class ReceiptPickerUnavailable extends ReceiptPickFailure {
  const ReceiptPickerUnavailable(this.cause, this.stackTrace)
    : super('Could not open the camera or gallery');

  final Object cause;
  final StackTrace stackTrace;
}

/// The device camera and gallery.
///
/// Implementations own every plugin type; none of them cross this boundary.
abstract interface class ReceiptPicker {
  /// The picked photo, or null when the member cancelled.
  Future<Result<ReceiptPhoto?, ReceiptPickFailure>> pick(ReceiptSource source);
}
