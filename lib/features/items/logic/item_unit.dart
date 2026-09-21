/// How an item is measured.
enum ItemUnit {
  kg('kg', 'kg'),
  g('g', 'g'),
  pcs('pcs', 'pcs'),
  l('l', 'L');

  const ItemUnit(this.key, this.label);

  /// Stored in Firestore. Stable, so a label can change without a migration.
  final String key;

  /// Shown to the user.
  final String label;

  static const ItemUnit fallback = ItemUnit.kg;

  static ItemUnit fromKey(String key) =>
      values.firstWhere((unit) => unit.key == key, orElse: () => fallback);
}
