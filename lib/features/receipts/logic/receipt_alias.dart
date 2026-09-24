import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../items/logic/item_unit.dart';

/// What a receipt line has been taught to mean.
final class ReceiptAlias extends Equatable {
  const ReceiptAlias({
    required this.rawTextNormalized,
    required this.itemId,
    required this.defaultQuantity,
    required this.defaultUnit,
    required this.shopName,
  });

  final String rawTextNormalized;
  final String itemId;

  /// The quantity used when a receipt does not print one.
  final double defaultQuantity;
  final ItemUnit defaultUnit;

  /// Where it was learned. Kept only to explain a surprising mapping; aliases
  /// apply at every shop.
  final String? shopName;

  @override
  List<Object?> get props => [
    rawTextNormalized,
    itemId,
    defaultQuantity,
    defaultUnit,
    shopName,
  ];
}

final _whitespace = RegExp(r'\s+');

/// The form two receipt lines are compared in: upper case, single spaced,
/// trimmed. Nothing looser, so lines that print differently stay distinct.
String normalizeReceiptText(String text) =>
    text.trim().replaceAll(_whitespace, ' ').toUpperCase();

/// The alias document for [rawTextNormalized]. Deterministic, so learning the
/// same wording again overwrites it instead of adding a second alias, and
/// base64url, so it never contains the `/` a document id cannot.
String aliasDocumentId(String rawTextNormalized) =>
    base64Url.encode(utf8.encode(rawTextNormalized)).replaceAll('=', '');
