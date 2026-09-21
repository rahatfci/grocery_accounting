/// Parses a decimal that may use either separator.
///
/// The household reads prices with a decimal comma, so `1,5` and `1.5` must
/// both be accepted rather than one of them silently failing.
double? parseDecimal(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String? validateName(String? value) =>
    (value ?? '').trim().isEmpty ? 'Enter a name' : null;

String? validateCategory(String? value) =>
    (value ?? '').trim().isEmpty ? 'Choose a category' : null;

/// A required amount: present, numeric, and not negative.
String? validateRequiredAmount(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return 'Enter a number';
  }
  final parsed = parseDecimal(raw);
  if (parsed == null) {
    return 'Enter a valid number';
  }
  if (parsed < 0) {
    return 'Cannot be negative';
  }
  return null;
}

/// An optional amount: absent, or numeric and greater than zero.
String? validateOptionalWeight(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return null;
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

/// The inverse of [parseDecimal] for prefilling a field.
///
/// A whole number loses its `.0`, because an item measured in pieces should
/// read `2`, not `2.0`. Null becomes empty, which is how an absent optional
/// value is shown.
String formatDecimal(double? value) {
  if (value == null) {
    return '';
  }
  if (value.isFinite && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
