import '../../items/logic/item.dart';
import '../../items/logic/item_category.dart';
import '../../items/logic/item_validation.dart';
import '../../members/logic/household_member.dart';
import '../../purchases/logic/purchase.dart';
import 'report_month.dart';

const _separator = ';';
const _lineBreak = '\r\n';

const _header = [
  'Date',
  'Shop',
  'Paid by',
  'Purchase total',
  'Receipt text',
  'Item',
  'Category',
  'Quantity',
  'Unit',
  'Line total',
  'Source',
];

/// The export's file name for [month], for example `grocery-2026-09.csv`.
String monthCsvFileName(DateTime month) =>
    'grocery-${month.year}-${month.month.toString().padLeft(2, '0')}.csv';

/// A month of purchases as CSV text in the form Italian Excel opens by
/// double-click: `;` separators, decimal commas, `dd/MM/yyyy` dates and CRLF
/// line endings. The byte order mark is the sharer's job, since it belongs
/// to the file's encoding, not to the text.
///
/// One row per purchase line. A purchase with no lines still gets one row, so
/// its spend is never lost from the export.
String monthCsv({
  required DateTime month,
  required Iterable<Purchase> purchases,
  required Iterable<Item> items,
  required Iterable<HouseholdMember> members,
}) {
  final from = monthStart(month);
  final to = nextMonth(from);
  final inMonth = [
    for (final purchase in purchases)
      if (!purchase.date.isBefore(from) && purchase.date.isBefore(to)) purchase,
  ]..sort((a, b) => a.date.compareTo(b.date));

  final itemsById = {for (final item in items) item.id: item};
  final namesById = {
    for (final member in members) member.id: member.displayName,
  };

  final rows = <List<String>>[_header];
  for (final purchase in inMonth) {
    final shared = [
      _date(purchase.date),
      _text(purchase.shopName),
      _text(namesById[purchase.paidByUserId] ?? purchase.paidByUserId),
      _amount(purchase.total),
    ];
    if (purchase.lines.isEmpty) {
      rows.add([...shared, '', '', '', '', '', '', purchase.source.key]);
      continue;
    }
    for (final line in purchase.lines) {
      final item = itemsById[line.itemId];
      rows.add([
        ...shared,
        _text(line.rawText),
        _text(item?.name ?? ''),
        _text(item == null ? '' : categoryLabel(item.category)),
        formatDecimal(line.quantity).replaceAll('.', ','),
        line.unit.label,
        _amount(line.lineTotal),
        purchase.source.key,
      ]);
    }
  }

  return rows.map((row) => row.map(_quote).join(_separator)).join(_lineBreak) +
      _lineBreak;
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Two decimals and a decimal comma, with no currency sign or grouping, so the
/// spreadsheet reads a number rather than text.
String _amount(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

/// Text a spreadsheet would otherwise run as a formula. Receipt text comes
/// from OCR and from members' typing, so it is treated as untrusted.
String _text(String value) =>
    value.isNotEmpty && '=+-@'.contains(value[0]) ? "'$value" : value;

String _quote(String field) {
  final needsQuotes =
      field.contains(_separator) ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  return needsQuotes ? '"${field.replaceAll('"', '""')}"' : field;
}
