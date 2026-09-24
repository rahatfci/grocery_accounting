import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';

final _today = DateTime(2026, 9, 24, 18);

/// A line at [row] (one row is 20 units tall) starting at [left].
OcrLine _at(String text, int row, {double left = 0, double width = 200}) =>
    OcrLine(
      text: text,
      left: left,
      top: row * 20.0,
      right: left + width,
      bottom: row * 20.0 + 16,
    );

/// Rows given in one column, top to bottom.
List<OcrLine> _column(List<String> rows) => [
  for (final (index, text) in rows.indexed) _at(text, index),
];

ReceiptReading _parse(List<OcrLine> lines) =>
    parseReceipt(lines, today: _today);

void main() {
  test('rebuilds rows from a description column and a price column', () {
    // The recogniser returns each column as its own run of lines, out of
    // row order.
    final lines = [
      _at('1,29', 1, left: 300, width: 40),
      _at('2,40', 2, left: 300, width: 40),
      _at('LATTE PS 1L', 1),
      _at('PANE CASERECCIO', 2),
      _at('24/09/2026', 0),
    ];

    final reading = _parse(lines);

    expect(reading.lines.map((l) => l.rawText), [
      'LATTE PS 1L',
      'PANE CASERECCIO',
    ]);
    expect(reading.lines.map((l) => l.lineTotal), [1.29, 2.40]);
    expect(reading.date, DateTime(2026, 9, 24));
  });

  test('a line reads as one piece at its price', () {
    final reading = _parse(_column(['UOVA FRESCHE 6 PZ   2,99 B']));

    expect(
      reading.lines.single,
      const ScannedLine(
        rawText: 'UOVA FRESCHE 6 PZ',
        quantity: 1,
        unit: ItemUnit.pcs,
        lineTotal: 2.99,
      ),
    );
  });

  test('the total comes from TOTALE, not SUBTOTALE, and ends the lines', () {
    final reading = _parse(
      _column([
        'RISO 1KG 1,80',
        'SUBTOTALE 1,80',
        'TOTALE EURO 1,80',
        'CONTANTI 5,00',
        'RESTO 3,20',
        'SACCHETTO 0,10',
      ]),
    );

    expect(reading.total, 1.80);
    expect(reading.lines.map((l) => l.rawText), ['RISO 1KG']);
  });

  test('a total that cannot be read is left empty, and still ends the '
      'lines', () {
    final reading = _parse(
      _column([
        'RISO 1KG 1,80',
        'TOTALE T0,00',
        'IMPORTO PAGATO 1,80',
        'A0rto 1,80',
      ]),
    );

    expect(reading.total, isNull);
    expect(reading.lines.single.rawText, 'RISO 1KG');
  });

  group('date', () {
    test('reads dd/MM/yyyy, dd-MM-yy and dd.MM.yyyy', () {
      expect(_parse(_column(['03/09/2026'])).date, DateTime(2026, 9, 3));
      expect(_parse(_column(['03-09-26 18:30'])).date, DateTime(2026, 9, 3));
      expect(_parse(_column(['03.09.2026'])).date, DateTime(2026, 9, 3));
    });

    test('ignores a future or impossible date and takes the next one', () {
      final reading = _parse(
        _column(['31/02/2026', '01/12/2026', '20/09/2026']),
      );

      expect(reading.date, DateTime(2026, 9, 20));
    });

    test('a dotted date is not read as a price', () {
      final reading = _parse(_column(['DATA 20.09.2026 ORA 18:30']));

      expect(reading.lines, isEmpty);
      expect(reading.date, DateTime(2026, 9, 20));
    });
  });

  group('quantity rows', () {
    test('a pieces row sets the line below it', () {
      final reading = _parse(_column(['2 x 1,29', 'YOGURT BIANCO 2,58']));

      expect(reading.lines.single.quantity, 2);
      expect(reading.lines.single.unit, ItemUnit.pcs);
      expect(reading.lines.single.lineTotal, 2.58);
    });

    test('a weight row sets kilograms', () {
      final reading = _parse(_column(['0,450 kg x 5,90', 'MELE GOLDEN 2,66']));

      expect(reading.lines.single.quantity, 0.45);
      expect(reading.lines.single.unit, ItemUnit.kg);
    });

    test('a row printed under the last line belongs to it', () {
      final reading = _parse(
        _column(['PANE 1,20', 'BANANE 1,77', '1,180 KG x 1,50']),
      );

      expect(reading.lines.first.quantity, 1);
      expect(reading.lines.last.quantity, 1.18);
      expect(reading.lines.last.unit, ItemUnit.kg);
    });

    test('never becomes a line itself, even with a price beside it', () {
      final reading = _parse(_column(['3 x 0,99 2,97', 'ACQUA NAT 2,97']));

      expect(reading.lines.single.rawText, 'ACQUA NAT');
      expect(reading.lines.single.quantity, 3);
    });
  });

  test('skips payment, tax and discount rows, but not words inside names', () {
    final reading = _parse(
      _column([
        'OLIO EXTRAVERGINE OLIVA 6,49',
        'SCONTO -1,00',
        'IVA 10% 0,59',
        'PAGAMENTO CARTA 5,49',
        'BANCOMAT 5,49',
        'ARROTONDAMENTO 0,01',
        'RESO VUOTO -0,10',
      ]),
    );

    expect(reading.lines.single.rawText, 'OLIO EXTRAVERGINE OLIVA');
  });

  test('skips rows without a product name or with a negative price', () {
    final reading = _parse(_column(['12 3,40', '-2,00', 'X 1,00', '€ 4,50']));

    expect(reading.lines, isEmpty);
  });

  test('strips the currency from a line', () {
    final reading = _parse(_column(['FORMAGGIO GRANA € 4,50']));

    expect(reading.lines.single.rawText, 'FORMAGGIO GRANA');
  });

  test('nothing readable gives an empty reading', () {
    expect(_parse(const []).isEmpty, isTrue);
    expect(_parse(_column(['GRAZIE E ARRIVEDERCI', '   '])).isEmpty, isTrue);
    expect(
      _parse([
        const OcrLine(text: 'X 1,00', left: 0, top: 5, right: 9, bottom: 5),
      ]).isEmpty,
      isTrue,
    );
  });

  test('reads what ML Kit returned for a real test receipt', () {
    // Recorded from the Android emulator on 2026-09-24, feature 10's device
    // run: the description and price columns come back as separate lines, out
    // of row order, and some prices with a gap after the comma.
    OcrLine line(double top, double bottom, double left, String text) =>
        OcrLine(
          text: text,
          left: left,
          top: top,
          right: left + 300,
          bottom: bottom,
        );
    final lines = [
      line(47, 69, 248, 'SUPERMERCATO TEST'),
      line(162, 183, 43, 'DOCUMENTO COMMERCIALE'),
      line(85, 107, 226, 'VIA ROMA 1 MILANO'),
      line(240, 262, 45, 'LATTE PS 1L'),
      line(281, 308, 46, '2 x 1, 29'),
      line(325, 346, 45, 'YOGURT BIANCO'),
      line(367, 388, 46, 'PANE CASERECCIO'),
      line(407, 435, 47, '0,450 kg x 5,90'),
      line(493, 514, 46, 'SUBTOTALE'),
      line(451, 472, 43, 'MELE GOLDEN'),
      line(534, 555, 44, 'TOTALE EURO'),
      line(619, 640, 44, 'RESTO'),
      line(577, 598, 46, 'PAGAMENTO CONTANTE'),
      line(693, 723, 43, '20/09/2026 18:42 DOC. N. 0042'),
      line(236, 267, 718, '1,29'),
      line(317, 351, 717, '2, 58'),
      line(362, 392, 717, '2, 40'),
      line(445, 476, 717, '2,66'),
      line(486, 518, 718, '8,93'),
      line(530, 559, 718, '8,93'),
      line(573, 601, 698, '10,00'),
      line(613, 645, 718, '1,07'),
    ];

    final reading = _parse(lines);

    expect(reading.total, 8.93);
    expect(reading.date, DateTime(2026, 9, 20));
    expect(reading.lines, const [
      ScannedLine(
        rawText: 'LATTE PS 1L',
        quantity: 1,
        unit: ItemUnit.pcs,
        lineTotal: 1.29,
      ),
      ScannedLine(
        rawText: 'YOGURT BIANCO',
        quantity: 2,
        unit: ItemUnit.pcs,
        lineTotal: 2.58,
      ),
      ScannedLine(
        rawText: 'PANE CASERECCIO',
        quantity: 1,
        unit: ItemUnit.pcs,
        lineTotal: 2.40,
      ),
      ScannedLine(
        rawText: 'MELE GOLDEN',
        quantity: 0.45,
        unit: ItemUnit.kg,
        lineTotal: 2.66,
      ),
    ]);
  });

  test('SUB-TOTALE and SUB TOTALE are never the total', () {
    for (final subtotal in ['SUB-TOTALE 9,00', 'SUB TOTALE 9,00']) {
      final reading = _parse(_column(['PANE 9,00', subtotal, 'TOTALE 8,50']));

      expect(reading.total, 8.50);
    }
  });

  test('an unreadable total is left empty rather than guessed', () {
    final reading = _parse(
      _column(['PANE 9,00', 'SUB-TOTALE 9,00', 'TOTALE COMPLESSIVO T0,00']),
    );

    expect(reading.total, isNull);
  });

  test('drops a VAT rate column from the name', () {
    final reading = _parse(
      _column(['ACQUA NATURALE 10% 2,50', 'PIZZA 22X 8,00']),
    );

    expect(reading.lines.map((l) => l.rawText), ['ACQUA NATURALE', 'PIZZA']);
  });

  test('reads an n.2 * 2,50 quantity row', () {
    final reading = _parse(_column(['n.2 * 2,50', 'COPERTO 5,00']));

    expect(reading.lines.single.quantity, 2);
  });

  group('a photo stored sideways', () {
    // The upright receipt: rows 40 apart, text 300 wide and 20 tall.
    final upright = [
      for (final (index, (name, price)) in [
        ('PANE CASERECCIO', '2,40'),
        ('LATTE PS 1L', '1,29'),
        ('TOTALE', '3,69'),
        ('20/09/2026', ''),
      ].indexed) ...[
        OcrLine(
          text: name,
          left: 0,
          top: index * 40.0,
          right: 300,
          bottom: index * 40.0 + 20,
        ),
        if (price.isNotEmpty)
          OcrLine(
            text: price,
            left: 500,
            top: index * 40.0,
            right: 560,
            bottom: index * 40.0 + 20,
          ),
      ],
    ];

    void expectReadable(ReceiptReading reading) {
      expect(reading.total, 3.69);
      expect(reading.date, DateTime(2026, 9, 20));
      expect(reading.lines.map((l) => l.rawText), [
        'PANE CASERECCIO',
        'LATTE PS 1L',
      ]);
    }

    test('reads a receipt turned a quarter to the left', () {
      // How an upright phone photo arrives: the boxes are in a frame turned
      // a quarter counter-clockwise from the receipt.
      final stored = [
        for (final line in upright)
          OcrLine(
            text: line.text,
            left: line.top,
            top: -line.right,
            right: line.bottom,
            bottom: -line.left,
          ),
      ];

      expectReadable(_parse(stored));
    });

    test('reads a receipt turned a quarter to the right', () {
      final stored = [
        for (final line in upright)
          OcrLine(
            text: line.text,
            left: -line.bottom,
            top: line.left,
            right: -line.top,
            bottom: line.right,
          ),
      ];

      expectReadable(_parse(stored));
    });
  });
}
