import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/pantry_view.dart';

final _now = DateTime(2026, 9, 26, 12);

Item _item(
  String name, {
  String category = 'pantry',
  double stock = 5,
  double threshold = 1,
  double usage = 0,
}) => Item(
  id: name.toLowerCase(),
  name: name,
  unit: ItemUnit.kg,
  category: category,
  avgPieceWeight: null,
  dailyUsage: usage,
  lowThreshold: threshold,
  stockAtBaseline: stock,
  baselineDate: _now,
);

void main() {
  final items = [
    _item('Rice', stock: 0.3, usage: 0.1),
    _item('Pasta', stock: 2, usage: 0.1),
    _item('Milk', category: 'dairy', stock: 0, usage: 0.5),
    _item('Soap', category: 'household'),
    _item('Baby food', category: 'Baby food'),
  ];

  test('the filter row counts all, running low and staples, then categories '
      'in use', () {
    expect(pantryFilters(items, now: _now).map((option) => option.label), [
      'All · 5',
      'Running low · 2',
      'Staples · 3',
      'Dairy & Eggs',
      'Pantry & Dry Goods',
      'Household & Cleaning',
      'Baby food',
    ]);
  });

  test('groups by category, built-ins first, names sorted inside', () {
    final groups = pantryGroups(items, now: _now);

    expect(groups.map((group) => group.label), [
      'Dairy & Eggs',
      'Pantry & Dry Goods',
      'Household & Cleaning',
      'Baby food',
    ]);
    expect(groups[1].items.map((item) => item.name), ['Pasta', 'Rice']);
  });

  test('running low keeps what is under its threshold, out included', () {
    final groups = pantryGroups(
      items,
      now: _now,
      filter: const RunningLowFilter(),
    );

    expect(groups.expand((group) => group.items).map((item) => item.name), [
      'Milk',
      'Rice',
    ]);
  });

  test('staples keeps what has a daily usage', () {
    final names = pantryGroups(
      items,
      now: _now,
      filter: const StaplesFilter(),
    ).expand((group) => group.items).map((item) => item.name);

    expect(names, containsAll(['Rice', 'Pasta', 'Milk']));
    expect(names, isNot(contains('Soap')));
  });

  test('a category filter keeps that category only', () {
    final groups = pantryGroups(
      items,
      now: _now,
      filter: const CategoryFilter('household'),
    );

    expect(groups.single.items.single.name, 'Soap');
  });

  test('the search matches anywhere in the name, ignoring case', () {
    final groups = pantryGroups(items, now: _now, query: '  ASTA ');

    expect(groups.single.items.single.name, 'Pasta');
  });

  test('an item with a blank category is grouped under other', () {
    final groups = pantryGroups([_item('Thing', category: '  ')], now: _now);

    expect(groups.single.label, 'Other');
    expect(groups.single.items.single.name, 'Thing');
  });

  test('nothing left after filtering is no groups at all', () {
    expect(pantryGroups(items, now: _now, query: 'caviar'), isEmpty);
  });
}
