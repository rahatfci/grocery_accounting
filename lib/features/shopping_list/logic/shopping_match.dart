import '../../items/logic/item.dart';
import 'shopping_entry.dart';

final _whitespace = RegExp(r'\s+');

/// The form two names are compared in: trimmed, single spaced, lowercase.
String normalizeEntryText(String text) =>
    text.trim().replaceAll(_whitespace, ' ').toLowerCase();

String? validateEntryText(String? value) =>
    (value ?? '').trim().isEmpty ? 'Enter something to buy' : null;

/// The id of the one catalogue item [text] names, or null.
///
/// Null as well when several items share the name, because a guessed link
/// would clear the entry on the wrong purchase. The name match at purchase
/// time still covers an unlinked entry.
String? linkedItemId(String text, Iterable<Item> items) {
  final wanted = normalizeEntryText(text);
  if (wanted.isEmpty) {
    return null;
  }
  final matches = [
    for (final item in items)
      if (item.id.isNotEmpty && normalizeEntryText(item.name) == wanted) item,
  ];
  return matches.length == 1 ? matches.single.id : null;
}

/// The ids of the entries a purchase of [purchasedItems] covers.
///
/// An entry is covered when it is linked to a purchased item, or when its text
/// names one. An item created on the purchase itself has no id yet, so it can
/// only match by name.
Set<String> entriesClearedBy(
  Iterable<ShoppingEntry> entries,
  Iterable<Item> purchasedItems,
) {
  final ids = <String>{};
  final names = <String>{};
  for (final item in purchasedItems) {
    if (item.id.isNotEmpty) {
      ids.add(item.id);
    }
    final name = normalizeEntryText(item.name);
    if (name.isNotEmpty) {
      names.add(name);
    }
  }

  return {
    for (final entry in entries)
      if (entry.id.isNotEmpty &&
          (ids.contains(entry.itemId) ||
              names.contains(normalizeEntryText(entry.text))))
        entry.id,
  };
}
