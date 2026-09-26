import '../../receipts/logic/receipt_reading.dart';

/// What reading a receipt found, as the review screen's receipt strip says
/// it: `Total, date and 11 lines found`.
String receiptFoundLabel(ReceiptReading reading) {
  final lines = reading.lines.length;
  final parts = [
    if (reading.total != null) 'total',
    if (reading.date != null) 'date',
    if (lines > 0) lines == 1 ? '1 line' : '$lines lines',
  ];
  if (parts.isEmpty) {
    return 'Nothing could be read. Fill it in by hand';
  }
  final listed = parts.length == 1
      ? parts.single
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  return '${listed[0].toUpperCase()}${listed.substring(1)} found';
}
