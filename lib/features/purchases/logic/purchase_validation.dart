import '../../items/logic/item_validation.dart';
import 'purchase_draft.dart';

/// A EUR amount: present, numeric, not negative, and no finer than a cent.
///
/// Nothing is silently rounded. A third decimal is refused rather than turned
/// into a number the member did not type.
String? validateMoney(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return 'Enter an amount';
  }
  final parsed = parseDecimal(raw);
  if (parsed == null) {
    return 'Enter a valid amount';
  }
  if (parsed < 0) {
    return 'Cannot be negative';
  }
  if (_decimalPlaces(raw) > 2) {
    return 'Use at most two decimals';
  }
  return null;
}

/// The receipt total, which must also be more than zero.
String? validateTotal(String? value) {
  final amount = validateMoney(value);
  if (amount != null) {
    return amount;
  }
  final parsed = parseDecimal((value ?? '').trim());
  if (parsed == null || parsed <= 0) {
    return 'Enter an amount greater than zero';
  }
  return null;
}

/// A line's own total. Zero is allowed: not every line on a receipt is priced.
String? validateLineTotal(String? value) => validateMoney(value);

String? validateShopName(String? value) =>
    (value ?? '').trim().isEmpty ? 'Enter a shop' : null;

String? validateQuantity(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return 'Enter a quantity';
  }
  final parsed = parseDecimal(raw);
  if (parsed == null) {
    return 'Enter a valid number';
  }
  if (parsed <= 0) {
    return 'Must be greater than zero';
  }
  return null;
}

/// A purchase cannot have happened tomorrow. Compared by day, so a shop trip
/// later today is fine.
String? validateDate(DateTime date, {required DateTime today}) {
  final day = DateTime(date.year, date.month, date.day);
  final limit = DateTime(today.year, today.month, today.day);
  return day.isAfter(limit) ? 'A purchase cannot be in the future' : null;
}

/// The reason [draft] cannot be committed yet, or null when it can.
///
/// One message at a time, in the order the fields appear on the screen, so the
/// commit button explains the nearest problem rather than all of them at once.
String? validateDraft(PurchaseDraft draft, {required DateTime today}) {
  final date = validateDate(draft.date, today: today);
  if (date != null) {
    return date;
  }
  final shop = validateShopName(draft.shopName);
  if (shop != null) {
    return shop;
  }
  final total = validateTotal(draft.totalText);
  if (total != null) {
    return total;
  }
  if (draft.paidByUserId.isEmpty) {
    return 'Choose who paid';
  }
  for (final line in draft.lines) {
    // An unmatched line has no item to measure, and records spend only.
    if (line.item case final item? when line.restockQuantity == null) {
      return '${item.name} cannot be measured in ${line.unit.label}';
    }
  }
  return null;
}

/// Digits after the separator, whichever separator was used.
int _decimalPlaces(String raw) {
  final normalized = raw.replaceAll(',', '.');
  final separator = normalized.lastIndexOf('.');
  return separator < 0 ? 0 : normalized.length - separator - 1;
}
