/// Where a purchase's data came from.
enum PurchaseSource {
  manual('manual'),
  scanned('scanned');

  const PurchaseSource(this.key);

  /// Stored in Firestore. Stable, so the wording can change without a
  /// migration.
  final String key;

  static const PurchaseSource fallback = PurchaseSource.manual;

  /// An unknown key reads as [fallback]: a shared document with a value this
  /// build does not know must still render.
  static PurchaseSource fromKey(String key) =>
      values.firstWhere((source) => source.key == key, orElse: () => fallback);
}
