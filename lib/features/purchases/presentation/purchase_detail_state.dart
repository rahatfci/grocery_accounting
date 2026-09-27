import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../logic/purchase.dart';

/// Where the receipt photo of the purchase on screen stands. Compared by
/// identity: a photo is megabytes, and comparing its bytes on every report
/// would cost more than drawing it again.
sealed class PurchasePhoto {
  const PurchasePhoto();
}

/// The purchase has no photo.
final class NoPurchasePhoto extends PurchasePhoto {
  const NoPurchasePhoto();
}

final class PurchasePhotoLoading extends PurchasePhoto {
  const PurchasePhotoLoading();
}

final class PurchasePhotoLoaded extends PurchasePhoto {
  const PurchasePhotoLoaded(this.bytes);

  final Uint8List bytes;
}

final class PurchasePhotoFailed extends PurchasePhoto {
  const PurchasePhotoFailed(this.message);

  /// Already worded for the member.
  final String message;
}

sealed class PurchaseDetailState extends Equatable {
  const PurchaseDetailState();

  @override
  List<Object?> get props => const [];
}

final class PurchaseDetailLoading extends PurchaseDetailState {
  const PurchaseDetailLoading();
}

final class PurchaseDetailLoaded extends PurchaseDetailState {
  const PurchaseDetailLoaded({required this.purchase, required this.photo});

  final Purchase purchase;
  final PurchasePhoto photo;

  @override
  List<Object?> get props => [purchase, photo];
}

/// The purchase document is gone.
final class PurchaseDetailMissing extends PurchaseDetailState {
  const PurchaseDetailMissing();
}

final class PurchaseDetailFailure extends PurchaseDetailState {
  const PurchaseDetailFailure(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}
