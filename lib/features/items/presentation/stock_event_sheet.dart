import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data_failure.dart';
import '../../../core/refusal_window.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/form_controls.dart';
import '../../auth/logic/app_user.dart';
import '../../purchases/logic/quantity_conversion.dart';
import '../logic/item.dart';
import '../logic/item_unit.dart';
import '../logic/item_validation.dart';
import '../logic/stock.dart';
import '../logic/stock_event.dart';
import 'items_cubit.dart';
import 'items_state.dart';

/// Opens the sheet for [type] on [item], writing through the caller's own
/// [ItemsCubit], handed over so the sheet works wherever it opens.
void openStockEventSheet(
  BuildContext context, {
  required Item item,
  required StockEventType type,
  required AppUser user,
}) {
  final cubit = context.read<ItemsCubit>();
  showAppSheet<void>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: StockEventSheet(item: item, type: type, user: user),
    ),
  );
}

/// Records a use, an adjustment or a recount of one item, showing what the
/// stock will be before it is saved.
class StockEventSheet extends StatefulWidget {
  const StockEventSheet({
    required this.item,
    required this.type,
    required this.user,
    super.key,
  });

  /// The item as it was when the sheet opened. The newest version from the
  /// stream is used when saving.
  final Item item;

  final StockEventType type;
  final AppUser user;

  @override
  State<StockEventSheet> createState() => _StockEventSheetState();
}

class _StockEventSheetState extends State<StockEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  late ItemUnit _unit = widget.item.unit;

  /// Only used for an adjustment. Starts unset: guessing a direction would let
  /// a hurried save move stock the wrong way.
  bool? _removing;

  bool _saving = false;
  DataFailure? _failure;

  bool get _isAdjustment => widget.type == StockEventType.adjustment;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFieldChanged([Object? _]) {
    setState(() => _failure = null);
  }

  /// The newest version of the item, so the stock is computed from the number
  /// behind the sheet, which follows the stream while the sheet is open.
  Item _currentItem(ItemsCubit cubit) {
    final state = cubit.state;
    if (state is ItemsLoaded) {
      for (final item in state.items) {
        if (item.id == widget.item.id) {
          return item;
        }
      }
    }
    return widget.item;
  }

  StockEvent? _event() {
    final quantity = parseDecimal(_quantityController.text);
    if (quantity == null || (_isAdjustment && _removing == null)) {
      return null;
    }
    final note = _noteController.text.trim();
    return StockEvent(
      itemId: widget.item.id,
      type: widget.type,
      quantity: _removing == true ? -quantity : quantity,
      unit: _unit,
      userId: widget.user.uid,
      note: note.isEmpty ? null : note,
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final event = _event();
    if (event == null) {
      return;
    }
    FocusScope.of(context).unfocus();

    final cubit = context.read<ItemsCubit>();
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _failure = null;
    });

    final result = await cubit
        .recordStockEvent(_currentItem(cubit), event)
        .timeout(refusalWindow, onTimeout: () => const Ok(null));

    if (!mounted) {
      return;
    }
    switch (result) {
      case Ok():
        navigator.pop();
      case Err(:final error):
        setState(() {
          _saving = false;
          _failure = error;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.watch<ItemsCubit>();
    final item = _currentItem(cubit);
    final state = cubit.state;
    final now = state is ItemsLoaded ? state.now : DateTime.now();
    final (title, quantityLabel, action) = switch (widget.type) {
      StockEventType.consumed => ('Log use', 'Amount used', 'Save use'),
      StockEventType.adjustment => (
        'Adjust stock',
        'Amount',
        'Save adjustment',
      ),
      StockEventType.recount => ('Recount', 'Counted amount', 'Save recount'),
    };
    final units = unitsFor(item);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SheetFrame(
        children: [
          SheetTitle(
            title: title,
            subtitle: Text(
              '${item.name} · '
              '${formatStock(currentStock(item, now: now), item.unit)} now',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (_isAdjustment)
            _DirectionField(
              removing: _removing,
              enabled: !_saving,
              onChanged: (removing) {
                setState(() => _removing = removing);
                _onFieldChanged();
              },
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: quantityLabel,
                  child: TextFormField(
                    controller: _quantityController,
                    enabled: !_saving,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        stockEventQuantityError(widget.type, value),
                    onChanged: _onFieldChanged,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: LabeledField(
                  label: 'Unit',
                  child: Padding(
                    // Sits level with the 52 px field beside it.
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SegmentedPicker<ItemUnit>(
                      segments: [
                        for (final unit in units)
                          Segment(value: unit, label: unit.label),
                      ],
                      selected: units.contains(_unit) ? _unit : units.first,
                      onChanged: _saving
                          ? null
                          : (unit) {
                              setState(() => _unit = unit);
                              _onFieldChanged();
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),
          LabeledField(
            label: 'Note (optional)',
            child: TextFormField(
              controller: _noteController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: _onFieldChanged,
              onFieldSubmitted: (_) => _save(),
            ),
          ),
          _Preview(item: item, event: _event(), now: now),
          if (_failure case final failure?)
            FailureMessage(message: failure.message),
          AppButton(
            label: action,
            expand: true,
            busy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// What the stock will be once the event is saved, worked out the way the
/// save works it out.
class _Preview extends StatelessWidget {
  const _Preview({required this.item, required this.event, required this.now});

  final Item item;
  final StockEvent? event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final before = currentStock(item, now: now);
    final event = this.event;
    final after = event == null ? null : baselineAfter(item, event, now: now);
    final color = switch (after) {
      null => AppColors.textTertiary,
      final value when value < (before < 0 ? 0 : before) => AppColors.negative,
      final value when value > before => AppColors.positive,
      _ => AppColors.textPrimary,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Text(
            'New stock',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              after == null
                  ? formatStock(before, item.unit)
                  : '${formatStock(before, item.unit)} → '
                        '${formatStock(after, item.unit)}',
              textAlign: TextAlign.end,
              style: text.bodyMediumStrong.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add or Remove, as a form field so an unchosen direction fails validation
/// alongside the quantity.
class _DirectionField extends StatelessWidget {
  const _DirectionField({
    required this.removing,
    required this.enabled,
    required this.onChanged,
  });

  final bool? removing;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Validates the field's own value, not [removing]: the form revalidates
    // from the field's state, which can run before this widget is rebuilt
    // with the new choice, and would then show a stale error.
    return FormField<bool>(
      initialValue: removing,
      validator: (value) => value == null ? 'Choose add or remove' : null,
      builder: (field) {
        final error = field.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedPicker<bool>(
              segments: const [
                Segment(value: false, label: 'Add', icon: Symbols.add_rounded),
                Segment(
                  value: true,
                  label: 'Remove',
                  icon: Symbols.remove_rounded,
                ),
              ],
              selected: removing,
              onChanged: enabled
                  ? (value) {
                      onChanged(value);
                      field.didChange(value);
                    }
                  : null,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s6),
                child: Text(
                  error,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.negative),
                ),
              ),
          ],
        );
      },
    );
  }
}
