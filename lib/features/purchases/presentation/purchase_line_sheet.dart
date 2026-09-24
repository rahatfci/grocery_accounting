import 'package:flutter/material.dart';

import '../../items/logic/item.dart';
import '../../items/logic/item_category.dart';
import '../../items/logic/item_unit.dart';
import '../../items/logic/item_validation.dart';
import '../logic/purchase_draft.dart';
import '../logic/purchase_validation.dart';
import '../logic/quantity_conversion.dart';

/// Adds or edits one line, on a sheet rather than a screen, so the purchase it
/// belongs to stays visible behind it.
///
/// Pops the finished line, or null when the member backs out.
class PurchaseLineSheet extends StatefulWidget {
  const PurchaseLineSheet({required this.items, this.line, super.key});

  /// Everything that can be picked: the catalogue, plus the items already
  /// created on this purchase.
  final List<Item> items;

  /// The line being edited, or null when adding one.
  final PurchaseDraftLine? line;

  @override
  State<PurchaseLineSheet> createState() => _PurchaseLineSheetState();
}

class _PurchaseLineSheetState extends State<PurchaseLineSheet> {
  /// Identity, not a value, so it can never collide with a real item.
  static final Object _newItemOption = Object();

  /// Never written. The commit stamps the real baseline pair. Fixed rather
  /// than the clock so two lines that create the same item are equal and merge
  /// into one document instead of two.
  static final DateTime _unwrittenBaseline =
      DateTime.fromMillisecondsSinceEpoch(0);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _lineTotalController = TextEditingController();

  Object? _selection;
  ItemUnit _lineUnit = ItemUnit.fallback;
  ItemUnit _newItemUnit = ItemUnit.fallback;
  String _newItemCategory = BuiltInCategory.other.key;

  bool get _creatingItem => identical(_selection, _newItemOption);

  bool get _isEditing => widget.line != null;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    if (line == null) {
      return;
    }
    _selection = line.item;
    _lineUnit = line.unit;
    _quantityController.text = formatDecimal(line.quantity);
    _lineTotalController.text = formatDecimal(line.lineTotal);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _lineTotalController.dispose();
    super.dispose();
  }

  /// The item this line is for: one from the picker, or the one being created
  /// on the spot.
  Item? _selectedItem() {
    final selection = _selection;
    if (selection is Item) {
      return selection;
    }
    return _creatingItem ? _newItem() : null;
  }

  /// An item the commit has to create. Zero daily usage, zero threshold and no
  /// average piece weight: a purchase knows what was bought, not how fast the
  /// household gets through it. The catalogue is where that is filled in.
  Item _newItem() => Item(
    id: '',
    name: _nameController.text.trim(),
    unit: _newItemUnit,
    category: _newItemCategory,
    avgPieceWeight: null,
    dailyUsage: 0,
    lowThreshold: 0,
    stockAtBaseline: 0,
    baselineDate: _unwrittenBaseline,
  );

  /// The units this line may be entered in. Before an item is chosen there is
  /// nothing to convert to, so all of them are offered and choosing an item
  /// narrows them.
  List<ItemUnit> get _unitOptions {
    final item = _selectedItem();
    return item == null ? ItemUnit.values : unitsFor(item);
  }

  void _onItemChanged(Object? selection) {
    setState(() {
      _selection = selection;
      _lineUnit = selection is Item ? selection.unit : _newItemUnit;
    });
  }

  void _onNewItemUnitChanged(ItemUnit unit) {
    setState(() {
      _newItemUnit = unit;
      // The line unit follows the item's, because the old one may no longer
      // convert to it.
      _lineUnit = unit;
    });
  }

  String? _validateItem(Object? value) =>
      value == null ? 'Choose an item' : null;

  void _save() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final item = _selectedItem();
    final quantity = parseDecimal(_quantityController.text);
    final lineTotal = parseDecimal(_lineTotalController.text);
    if (item == null || quantity == null || lineTotal == null) {
      return;
    }

    Navigator.of(context).pop(
      PurchaseDraftLine(
        item: item,
        quantity: quantity,
        unit: _lineUnit,
        lineTotal: lineTotal,
        // Matching a scanned line keeps what the receipt called it.
        scannedText: widget.line?.scannedText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitOptions = _unitOptions;

    return Padding(
      // Lifts the sheet clear of the keyboard rather than hiding the fields
      // behind it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit line' : 'Add line',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Object>(
                  initialValue: _selection,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Item',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in widget.items)
                      DropdownMenuItem<Object>(
                        value: item,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    DropdownMenuItem<Object>(
                      value: _newItemOption,
                      child: const Text('New item'),
                    ),
                  ],
                  validator: _validateItem,
                  onChanged: _onItemChanged,
                ),
                if (_creatingItem) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'New item name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    validator: validateName,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ItemUnit>(
                    initialValue: _newItemUnit,
                    decoration: const InputDecoration(
                      labelText: 'Measured in',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final unit in ItemUnit.values)
                        DropdownMenuItem(value: unit, child: Text(unit.label)),
                    ],
                    onChanged: (unit) {
                      if (unit != null) {
                        _onNewItemUnitChanged(unit);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _newItemCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final category in availableCategories(widget.items))
                        DropdownMenuItem(
                          value: category,
                          child: Text(
                            categoryLabel(category),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (category) {
                      if (category != null) {
                        setState(() => _newItemCategory = category);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: validateQuantity,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ItemUnit>(
                        initialValue: unitOptions.contains(_lineUnit)
                            ? _lineUnit
                            : unitOptions.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final unit in unitOptions)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: (unit) {
                          if (unit != null) {
                            setState(() => _lineUnit = unit);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lineTotalController,
                  decoration: const InputDecoration(
                    labelText: 'Line total',
                    border: OutlineInputBorder(),
                    prefixText: '€ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: validateLineTotal,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(_isEditing ? 'Save line' : 'Add line'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
