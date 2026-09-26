import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/home/logic/greeting.dart';

void main() {
  String at(int hour) => greetingFor(DateTime(2026, 9, 26, hour, 30));

  test('morning runs from five until noon', () {
    expect(at(5), 'Good morning');
    expect(at(11), 'Good morning');
  });

  test('afternoon runs from noon until six', () {
    expect(at(12), 'Good afternoon');
    expect(at(17), 'Good afternoon');
  });

  test('evening covers the rest, including the small hours', () {
    expect(at(18), 'Good evening');
    expect(at(23), 'Good evening');
    expect(at(2), 'Good evening');
  });
}
