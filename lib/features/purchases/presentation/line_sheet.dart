import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/notes.dart';
import '../../items/logic/item.dart';
import '../../items/logic/item_category.dart';
import '../../items/logic/item_unit.dart';
import '../../items/logic/item_validation.dart';
import '../../items/presentation/category_icons.dart';
import '../logic/money.dart';
import '../logic/purchase_draft.dart';
import '../logic/purchase_validation.dart';
import '../logic/quantity_conversion.dart';
import '../logic/receipt_matching.dart';
import '../logic/review_lines.dart';

/// What the line sheet decided.
sealed class LineSheetResult {
  const LineSheetResult();
}

/// The line as it should now read: matched, edited or added.
final class LineChosen extends LineSheetResult {
  const LineChosen(this.line);

  final PurchaseDraftLine line;
}

/// The line should go.
final class LineRemoved extends LineSheetResult {
  const LineRemoved();
}

/// Matches a receipt line to a pantry item, edits a line, or adds one by
/// hand. Null when dismissed.
Future<LineSheetResult?> showLineSheet(
  BuildContext context, {
  required List<Item> items,
  PurchaseDraftLine? line,
}) => showAppSheet<LineSheetResult>(
  context,
  builder: (_) => LineSheet(items: items, line: line),
);

/// On a sheet rather than a screen, so the purchase stays in view behind it.
class LineSheet extends StatefulWidget {
  const LineSheet({required this.items, this.line, super.key});

  /// Everything that can be picked: the catalogue, plus the items already
  /// created on this purchase.
  final List<Item> items;

  /// The line being matched or edited, or null when adding one.
  final PurchaseDraftLine? line;

  @override
  State<LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<LineSheet> {
  /// Never written. The commit stamps the real baseline pair. Fixed rather
  /// than the clock so two lines that create the same item are equal and merge
  /// into one document instead of two.
  static final DateTime _unwrittenBaseline =
      DateTime.fromMillisecondsSinceEpoch(0);

  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _lineTotalController = TextEditingController();
  final _nameController = TextEditingController();

  Item? _selected;
  ItemUnit _unit = ItemUnit.fallback;

  /// Showing the new pantry item form in place of the search.
  bool _creating = false;
  ItemUnit _newItemUnit = ItemUnit.fallback;
  String? _newItemCategory;

  /// Only shown once the member has tried to confirm without a choice.
  bool _itemMissing = false;
  bool _categoryMissing = false;

  /// The receipt's wording, for a line read off one.
  String? get _raw {
    final raw = widget.line?.scannedText?.trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    if (line == null) {
      return;
    }
    _selected = line.item;
    _unit = line.unit;
    _newItemUnit = line.item?.unit ?? line.unit;
    _quantityController.text = formatDecimal(line.quantity);
    _lineTotalController.text = formatAmountInput(line.lineTotal);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _lineTotalController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.line) {
    null => 'Add line',
    final line when !line.isMatched => 'Match this line',
    _ => 'Edit line',
  };

  String get _confirmLabel => switch (widget.line) {
    null => 'Add line',
    final line when !line.isMatched => 'Match line',
    _ => 'Save line',
  };

  /// Before an item is chosen there is nothing to convert to, so every unit
  /// is offered; choosing one narrows them.
  List<ItemUnit> get _unitOptions => switch (_selected) {
    final item? => unitsFor(item),
    null => ItemUnit.values,
  };

  void _select(Item item) {
    setState(() {
      _selected = item;
      _itemMissing = false;
      // The unit the line was read in stays when it converts, so 400 g of an
      // item kept in kg stays 400 g rather than becoming 400 kg.
      if (!unitsFor(item).contains(_unit)) {
        _unit = item.unit;
      }
    });
  }

  /// The name a new item starts with: the receipt's wording tidied up, or
  /// what was searched for.
  String _suggestedName() {
    final fromReceipt = suggestedItemName(_raw ?? '');
    if (fromReceipt.isNotEmpty) {
      return fromReceipt;
    }
    final query = _searchController.text.trim();
    return query.isEmpty ? '' : query[0].toUpperCase() + query.substring(1);
  }

  void _startCreating() {
    setState(() {
      _creating = true;
      _categoryMissing = false;
      _nameController.text = _suggestedName();
    });
  }

  /// A name already in the pantry is picked, not created twice.
  String? _validateNewName(String? value) {
    final missing = validateName(value);
    if (missing != null) {
      return missing;
    }
    final name = (value ?? '').trim().toLowerCase();
    final taken = widget.items.any(
      (item) => item.name.trim().toLowerCase() == name,
    );
    return taken ? 'Already in the pantry. Pick it from the list' : null;
  }

  void _confirmMatch() {
    final valid = _formKey.currentState?.validate() ?? false;
    final item = _selected;
    if (item == null) {
      setState(() => _itemMissing = true);
      return;
    }
    final quantity = parseDecimal(_quantityController.text);
    // A receipt line keeps the price the receipt printed.
    final lineTotal = _raw == null
        ? parseDecimal(_lineTotalController.text)
        : widget.line?.lineTotal;
    if (!valid || quantity == null || lineTotal == null) {
      return;
    }
    Navigator.of(context).pop(
      LineChosen(
        PurchaseDraftLine(
          item: item,
          quantity: quantity,
          unit: _unit,
          lineTotal: lineTotal,
          scannedText: widget.line?.scannedText,
        ),
      ),
    );
  }

  /// An item the commit has to create. Zero daily usage, zero threshold and
  /// no average piece weight: a purchase knows what was bought, not how fast
  /// the household gets through it. The pantry is where that is filled in.
  void _confirmNewItem() {
    final valid = _formKey.currentState?.validate() ?? false;
    final category = _newItemCategory;
    if (category == null) {
      setState(() => _categoryMissing = true);
      return;
    }
    final quantity = parseDecimal(_quantityController.text);
    final lineTotal = parseDecimal(_lineTotalController.text);
    if (!valid || quantity == null || lineTotal == null) {
      return;
    }
    final item = Item(
      id: '',
      name: _nameController.text.trim(),
      unit: _newItemUnit,
      category: category,
      avgPieceWeight: null,
      dailyUsage: 0,
      lowThreshold: 0,
      stockAtBaseline: 0,
      baselineDate: _unwrittenBaseline,
    );
    Navigator.of(context).pop(
      LineChosen(
        PurchaseDraftLine(
          item: item,
          quantity: quantity,
          unit: _newItemUnit,
          lineTotal: lineTotal,
          scannedText: widget.line?.scannedText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SheetFrame(
        children: _creating ? _newItemChildren() : _matchChildren(),
      ),
    );
  }

  Widget? _receiptChip() {
    final raw = _raw;
    final line = widget.line;
    if (raw == null || line == null) {
      return null;
    }
    return _ReceiptLineChip(rawText: raw, lineTotal: line.lineTotal);
  }

  List<Widget> _matchChildren() {
    final raw = _raw;
    final selected = _selected;
    final candidates = matchCandidates(
      widget.items,
      _searchController.text,
      selected: selected,
    );
    final text = Theme.of(context).textTheme;

    return [
      SheetTitle(title: _title, subtitle: _receiptChip()),
      LabeledField(
        label: 'Pantry item',
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search the pantry',
            prefixIcon: const Icon(Symbols.search_rounded, size: 20),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Symbols.close_rounded, size: 20),
                    tooltip: 'Clear search',
                    onPressed: () => setState(_searchController.clear),
                  ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in candidates) ...[
            _ItemOption(
              item: item,
              selected: item == selected,
              onTap: () => _select(item),
            ),
            const SizedBox(height: AppSpace.s4),
          ],
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s12,
              ),
              child: Text(
                'Nothing in the pantry is called that',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          _CreateOption(name: _suggestedName(), onTap: _startCreating),
          if (_itemMissing)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                'Choose an item',
                style: text.bodySmall?.copyWith(color: AppColors.negative),
              ),
            ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: LabeledField(
              label: 'Quantity',
              child: _NumberField(
                controller: _quantityController,
                validator: validateQuantity,
                // The learning note repeats the quantity as it is typed.
                onChanged: () => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Padding(
              // Lines the 44 px control up with the 52 px field beside it.
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: LabeledField(
                label: 'Unit',
                child: SegmentedPicker<ItemUnit>(
                  segments: [
                    for (final unit in _unitOptions)
                      Segment(value: unit, label: unit.label),
                  ],
                  selected: _unit,
                  onChanged: (unit) => setState(() => _unit = unit),
                ),
              ),
            ),
          ),
        ],
      ),
      if (raw == null)
        LabeledField(
          label: 'Line total',
          child: _NumberField(
            controller: _lineTotalController,
            validator: validateLineTotal,
            money: true,
          ),
        ),
      if (raw != null && selected != null)
        InfoNote(
          brand: true,
          icon: Symbols.auto_awesome_rounded,
          text: learningNote(
            rawText: raw,
            itemName: selected.name,
            quantity: parseDecimal(_quantityController.text),
            unit: _unit,
          ),
        ),
      _SheetButtons(
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.of(context).pop(),
        primaryLabel: _confirmLabel,
        onPrimary: _confirmMatch,
      ),
      if (widget.line != null)
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(const LineRemoved()),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Remove line'),
          ),
        ),
    ];
  }

  List<Widget> _newItemChildren() {
    final text = Theme.of(context).textTheme;
    return [
      SheetTitle(title: 'New pantry item', subtitle: _receiptChip()),
      LabeledField(
        label: 'Name',
        child: TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: _validateNewName,
        ),
      ),
      LabeledField(
        label: 'Measured in',
        child: SegmentedPicker<ItemUnit>(
          segments: [
            for (final unit in ItemUnit.values)
              Segment(value: unit, label: unit.label),
          ],
          selected: _newItemUnit,
          onChanged: (unit) => setState(() => _newItemUnit = unit),
        ),
      ),
      LabeledField(
        label: 'Category',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final category in availableCategories(widget.items))
                  ChoicePill(
                    label: categoryLabel(category),
                    selected: category == _newItemCategory,
                    onTap: () => setState(() {
                      _newItemCategory = category;
                      _categoryMissing = false;
                    }),
                  ),
              ],
            ),
            if (_categoryMissing)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s6),
                child: Text(
                  'Choose a category',
                  style: text.bodySmall?.copyWith(color: AppColors.negative),
                ),
              ),
          ],
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LabeledField(
              label: 'Quantity',
              child: _NumberField(
                controller: _quantityController,
                validator: validateQuantity,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: LabeledField(
              label: 'Line total',
              child: _NumberField(
                controller: _lineTotalController,
                validator: validateLineTotal,
                money: true,
              ),
            ),
          ),
        ],
      ),
      const InfoNote(
        text:
            'Daily usage and a low threshold can be set later in the Pantry. '
            'Until then it is not treated as a staple.',
      ),
      _SheetButtons(
        secondaryLabel: 'Back',
        onSecondary: () => setState(() => _creating = false),
        primaryLabel: 'Add line',
        onPrimary: _confirmNewItem,
      ),
    ];
  }
}

/// The receipt's wording and price, so the member can see what is being
/// matched while choosing.
class _ReceiptLineChip extends StatelessWidget {
  const _ReceiptLineChip({required this.rawText, required this.lineTotal});

  final String rawText;
  final double lineTotal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          decoration: BoxDecoration(
            color: AppColors.subtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.receipt_long_rounded,
                size: 18,
                color: AppColors.iconSecondary,
              ),
              const SizedBox(width: AppSpace.s8),
              Flexible(
                child: Text(
                  rawText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMediumStrong,
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                formatEuro(lineTotal),
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemOption extends StatelessWidget {
  const _ItemOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final Item item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? AppColors.brandSubtle : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s12,
            ),
            child: Row(
              children: [
                IconTile(
                  icon: categoryIcon(item.category),
                  size: 36,
                  iconSize: 20,
                  radius: AppRadius.sm,
                  background: selected ? AppColors.surface : AppColors.subtle,
                  color: selected
                      ? AppColors.iconPrimary
                      : AppColors.iconSecondary,
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: RowText(
                    title: item.name,
                    subtitle:
                        '${categoryLabel(item.category)} · ${item.unit.label}',
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? Symbols.radio_button_checked_rounded
                        : Symbols.radio_button_unchecked_rounded,
                    size: 24,
                    color: selected ? AppColors.brand : AppColors.iconSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CustomPaint(
      painter: const _DashedOutline(
        color: AppColors.borderDefault,
        radius: AppRadius.md,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s12,
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.add_rounded,
                  size: 22,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: RowText(
                    title: name.isEmpty
                        ? 'Create a new item'
                        : 'Create “$name”',
                    subtitle: 'As a new pantry item',
                    titleStyle: text.bodyLargeStrong.copyWith(
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dashed edge the design gives an option that makes something new.
class _DashedOutline extends CustomPainter {
  const _DashedOutline({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += _dash + _gap) {
        canvas.drawPath(metric.extractPath(start, start + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.validator,
    this.money = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  /// Shows the euro sign in front.
  final bool money;

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixText: money ? '€ ' : null,
        errorMaxLines: 3,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: validator,
      onChanged: onChanged == null ? null : (_) => onChanged(),
    );
  }
}

class _SheetButtons extends StatelessWidget {
  const _SheetButtons({
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: secondaryLabel,
            variant: AppButtonVariant.secondary,
            onPressed: onSecondary,
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: AppButton(label: primaryLabel, onPressed: onPrimary),
        ),
      ],
    );
  }
}
