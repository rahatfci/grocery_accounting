import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/refusal_window.dart';
import '../../../core/result.dart';
import '../../../core/widgets/failure_message.dart';
import '../../auth/logic/app_user.dart';
import '../../purchases/logic/quantity_conversion.dart';
import '../logic/item.dart';
import '../logic/item_unit.dart';
import '../logic/item_validation.dart';
import '../logic/stock_event.dart';
import 'items_cubit.dart';
import 'items_state.dart';

/// Opens the sheet for [type] on [item], writing through the caller's own
/// [ItemsCubit]. A sheet is a new route, so the cubit is handed over rather
/// than found by lookup.
void openStockEventSheet(
  BuildContext context, {
  required Item item,
  required StockEventType type,
  required AppUser user,
}) {
  final cubit = context.read<ItemsCubit>();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: StockEventSheet(item: item, type: type, user: user),
    ),
  );
}

/// Records a use, an adjustment or a recount of one item.
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
    if (_failure != null) {
      setState(() => _failure = null);
    }
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

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final quantity = parseDecimal(_quantityController.text);
    if (quantity == null) {
      return;
    }
    FocusScope.of(context).unfocus();

    final cubit = context.read<ItemsCubit>();
    final navigator = Navigator.of(context);
    final note = _noteController.text.trim();
    final event = StockEvent(
      itemId: widget.item.id,
      type: widget.type,
      quantity: _removing == true ? -quantity : quantity,
      unit: _unit,
      userId: widget.user.uid,
      note: note.isEmpty ? null : note,
    );

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
    final theme = Theme.of(context);
    final (title, quantityLabel) = switch (widget.type) {
      StockEventType.consumed => ('Log use', 'Amount used'),
      StockEventType.adjustment => ('Adjust stock', 'Amount'),
      StockEventType.recount => ('Recount', 'Counted amount'),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  widget.item.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                if (_isAdjustment) ...[
                  _DirectionField(
                    removing: _removing,
                    enabled: !_saving,
                    onChanged: (removing) {
                      setState(() => _removing = removing);
                      _onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _quantityController,
                        enabled: !_saving,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: quantityLabel,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            stockEventQuantityError(widget.type, value),
                        onChanged: _onFieldChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ItemUnit>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final unit in unitsFor(widget.item))
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (unit) {
                                if (unit != null) {
                                  setState(() => _unit = unit);
                                  _onFieldChanged();
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onChanged: _onFieldChanged,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_failure case final failure?) ...[
                  const SizedBox(height: 16),
                  FailureMessage(message: failure.message),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
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
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Add'),
                  icon: Icon(Icons.add),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Remove'),
                  icon: Icon(Icons.remove),
                ),
              ],
              selected: {?removing},
              emptySelectionAllowed: true,
              onSelectionChanged: enabled
                  ? (selection) {
                      if (selection.isNotEmpty) {
                        onChanged(selection.first);
                        field.didChange(selection.first);
                      }
                    }
                  : null,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
