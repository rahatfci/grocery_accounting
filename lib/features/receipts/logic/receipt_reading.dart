import 'package:equatable/equatable.dart';

import '../../items/logic/item_unit.dart';

/// One line of text the recogniser found, and where it sits on the photo.
///
/// Plain numbers rather than a `Rect`, so this file stays free of Flutter.
final class OcrLine extends Equatable {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;

  @override
  List<Object?> get props => [text, left, top, right, bottom];
}

/// One priced row of the receipt, not yet matched to anything.
final class ScannedLine extends Equatable {
  const ScannedLine({
    required this.rawText,
    required this.quantity,
    required this.unit,
    required this.lineTotal,
    this.quantityRead = false,
  });

  /// The receipt's own wording, kept so a mis-mapping stays diagnosable.
  final String rawText;
  final double quantity;
  final ItemUnit unit;
  final double lineTotal;

  /// Whether the receipt printed the quantity. When it did not, the 1 piece
  /// here is only a placeholder that a learned alias may replace.
  final bool quantityRead;

  ScannedLine withQuantity(double quantity, ItemUnit unit) => ScannedLine(
    rawText: rawText,
    quantity: quantity,
    unit: unit,
    lineTotal: lineTotal,
    quantityRead: true,
  );

  @override
  List<Object?> get props => [rawText, quantity, unit, lineTotal, quantityRead];
}

/// What could be read off a receipt. Every part is optional: whatever is not
/// certain is left for the member to fill in.
final class ReceiptReading extends Equatable {
  const ReceiptReading({this.total, this.date, this.lines = const []});

  static const empty = ReceiptReading();

  final double? total;

  /// The day of the purchase, never in the future.
  final DateTime? date;

  final List<ScannedLine> lines;

  bool get isEmpty => total == null && date == null && lines.isEmpty;

  @override
  List<Object?> get props => [total, date, lines];
}

final _price = RegExp(r'(?<![\d.,])-?\d{1,5}[.,]\d{2}(?![\d.,])');
final _date = RegExp(r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b');
final _quantityRow = RegExp(
  r'^\s*(?:N\.?\s*)?(\d+(?:[.,]\d+)?)\s*(KG)?\s*[X*]\s*\d{1,5}[.,]\d{2}',
);

/// `TOTALE`, but not `SUBTOTALE`, `SUB TOTALE` or `SUB-TOTALE`: a hyphen is a
/// word boundary, so the prefix has to be matched to be excluded.
final _totalWord = RegExp(r'\b(SUB[\s-]?)?TOTALE\b');

/// A VAT rate printed in its own column, which row rebuilding joins onto the
/// product name. Recognisers read the `%` as `x` about as often.
final _vatRate = RegExp(r'\s+\d{1,2}\s?[%X]$', caseSensitive: false);

/// ML Kit sometimes reads a gap after the decimal comma: `2,58` as `2, 58`.
final _splitDecimal = RegExp(r'(\d)([.,])\s+(\d{2})(?!\d)');
final _letters = RegExp(r'[A-Z]');

/// Words that mark a row as payment, change, tax or an adjustment rather than
/// something bought. Matched as whole words: `IVA` must not catch `OLIVA`.
final _notALine = RegExp(
  r'\b(TOTALE|SUBTOTALE|CONTANTI|RESTO|IVA|PAGAMENTO|CARTA|BANCOMAT|SCONTO|'
  r'RESO|ARROTONDAMENTO|IMPORTO|ABBUONO)\b',
);

/// Reads a total, a date and priced lines from recognised text.
///
/// Generic rules only, from the patterns the plan names. Receipts from
/// different chains will need tuning once real ones are available.
ReceiptReading parseReceipt(List<OcrLine> lines, {required DateTime today}) {
  // A photo taken upright on a phone is often stored sideways with a rotation
  // flag. The recogniser honours the flag when reading the words, but reports
  // their boxes in the stored frame, so every line comes back taller than it
  // is wide. Which way it was turned cannot be told from the boxes alone, so
  // both ways are read and the one that makes more sense wins.
  if (!_looksSideways(lines)) {
    return _parseUpright(lines, today: today);
  }
  final clockwise = _parseUpright([
    for (final line in lines) _turnedClockwise(line),
  ], today: today);
  final counterClockwise = _parseUpright([
    for (final line in lines) _turnedCounterClockwise(line),
  ], today: today);
  return _score(counterClockwise) > _score(clockwise)
      ? counterClockwise
      : clockwise;
}

/// Whether most lines are taller than they are wide, which text never is.
bool _looksSideways(List<OcrLine> lines) {
  final usable = [
    for (final line in lines)
      if (line.text.trim().length > 3) line,
  ];
  if (usable.isEmpty) {
    return false;
  }
  final tall = usable.where((line) => line.height > line.right - line.left);
  return tall.length * 2 > usable.length;
}

/// The stored frame turned a quarter to the right: its left edge becomes the
/// top of the receipt, and its bottom edge the receipt's left.
OcrLine _turnedClockwise(OcrLine line) => OcrLine(
  text: line.text,
  left: -line.bottom,
  top: line.left,
  right: -line.top,
  bottom: line.right,
);

OcrLine _turnedCounterClockwise(OcrLine line) => OcrLine(
  text: line.text,
  left: line.top,
  top: -line.right,
  right: line.bottom,
  bottom: -line.left,
);

/// How much of a receipt a reading found. A total and a date are worth more
/// than a line, because a wrong orientation rarely produces either.
int _score(ReceiptReading reading) =>
    reading.lines.length +
    (reading.total == null ? 0 : 3) +
    (reading.date == null ? 0 : 2);

ReceiptReading _parseUpright(List<OcrLine> lines, {required DateTime today}) {
  final rows = _rows(lines);
  if (rows.isEmpty) {
    return ReceiptReading.empty;
  }

  final date = _firstDate(rows, today);

  double? total;
  final scanned = <ScannedLine>[];
  ({double quantity, ItemUnit unit})? pending;

  for (final row in rows) {
    final upper = row.toUpperCase();
    final withoutDates = upper.replaceAll(_date, ' ');

    final totalWord = _totalWord.firstMatch(upper);
    if (totalWord != null && totalWord[1] == null) {
      final price = _lastPrice(withoutDates);
      if (price != null && price.value > 0) {
        total = price.value;
      }
      // Anything under the total is payment and change, not purchases, even
      // when the total itself was misread.
      break;
    }

    final quantity = _quantity(withoutDates);
    if (quantity != null) {
      pending = quantity;
      continue;
    }

    if (_notALine.hasMatch(upper)) {
      continue;
    }
    final price = _lastPrice(withoutDates);
    if (price == null || price.value < 0) {
      continue;
    }
    final text = row.substring(0, price.start).replaceAll('€', '').trim();
    final label = text
        .replaceAll(RegExp(r'\bEUR\b', caseSensitive: false), '')
        .trim()
        .replaceFirst(_vatRate, '');
    if (_letters.allMatches(label.toUpperCase()).length < 2) {
      continue;
    }

    var line = ScannedLine(
      rawText: label.trim(),
      quantity: 1,
      unit: ItemUnit.pcs,
      lineTotal: price.value,
    );
    if (pending != null) {
      line = line.withQuantity(pending.quantity, pending.unit);
      pending = null;
    }
    scanned.add(line);
  }

  // A quantity row printed under the last line belongs to that line.
  if (pending != null && scanned.isNotEmpty) {
    scanned.add(
      scanned.removeLast().withQuantity(pending.quantity, pending.unit),
    );
  }

  return ReceiptReading(total: total, date: date, lines: scanned);
}

/// Rebuilds the receipt's rows. A recogniser often returns the description
/// column and the price column as separate lines, so lines are grouped by
/// height on the page rather than taken in the order they arrive.
List<String> _rows(List<OcrLine> lines) {
  final usable = [
    for (final line in lines)
      if (line.text.trim().isNotEmpty && line.height > 0) line,
  ]..sort((a, b) => a.centerY.compareTo(b.centerY));
  if (usable.isEmpty) {
    return const [];
  }

  final heights = [for (final line in usable) line.height]..sort();
  final tolerance = heights[heights.length ~/ 2] / 2;

  final rows = <List<OcrLine>>[];
  for (final line in usable) {
    final current = rows.isEmpty ? null : rows.last;
    if (current != null &&
        (line.centerY - _meanCenter(current)).abs() <= tolerance) {
      current.add(line);
    } else {
      rows.add([line]);
    }
  }

  return [
    for (final row in rows)
      ([...row]..sort((a, b) => a.left.compareTo(b.left)))
          .map((line) => line.text.trim())
          .join(' ')
          .replaceAllMapped(
            _splitDecimal,
            (match) => '${match[1]}${match[2]}${match[3]}',
          ),
  ];
}

double _meanCenter(List<OcrLine> row) =>
    row.fold<double>(0, (sum, line) => sum + line.centerY) / row.length;

({double value, int start})? _lastPrice(String text) {
  final matches = _price.allMatches(text).toList();
  if (matches.isEmpty) {
    return null;
  }
  final match = matches.last;
  final value = double.tryParse((match[0] ?? '').replaceAll(',', '.'));
  return value == null ? null : (value: value, start: match.start);
}

({double quantity, ItemUnit unit})? _quantity(String upperText) {
  final match = _quantityRow.firstMatch(upperText);
  if (match == null) {
    return null;
  }
  // A row that also names the product is a line with its quantity inline,
  // which the generic rules do not try to split.
  final rest = upperText
      .substring(match.end)
      .replaceAll(RegExp(r'\bEUR\b'), '');
  if (_letters.allMatches(rest).length >= 2) {
    return null;
  }
  final quantity = double.tryParse((match[1] ?? '').replaceAll(',', '.'));
  if (quantity == null || quantity <= 0) {
    return null;
  }
  return (
    quantity: quantity,
    unit: match.group(2) == null ? ItemUnit.pcs : ItemUnit.kg,
  );
}

DateTime? _firstDate(List<String> rows, DateTime today) {
  final limit = DateTime(today.year, today.month, today.day);
  for (final row in rows) {
    for (final match in _date.allMatches(row)) {
      final day = int.tryParse(match[1] ?? '');
      final month = int.tryParse(match[2] ?? '');
      final rawYear = match[3] ?? '';
      final parsedYear = int.tryParse(rawYear);
      if (day == null || month == null || parsedYear == null) {
        continue;
      }
      final year = rawYear.length == 2 ? 2000 + parsedYear : parsedYear;
      final date = DateTime(year, month, day);
      // DateTime rolls 31/02 over into March; a real date survives the trip.
      final real = date.year == year && date.month == month && date.day == day;
      if (real && !date.isAfter(limit)) {
        return date;
      }
    }
  }
  return null;
}
