import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data_failure.dart';
import '../../../core/refusal_window.dart';
import '../../../core/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/notes.dart';
import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/item_unit.dart';
import '../logic/item_validation.dart';
import 'items_cubit.dart';
import 'items_state.dart';

/// Opens the form, to create when [item] is null and to edit when it is not.
///
/// The form writes through the caller's own [ItemsCubit], so it is handed the
/// existing instance rather than building a second one.
void openItemForm(BuildContext context, {Item? item}) {
  final cubit = context.read<ItemsCubit>();
  final state = cubit.state;
  final items = state is ItemsLoaded ? state.items : const <Item>[];

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ItemFormPage(categories: availableCategories(items), item: item),
      ),
    ),
  );
}

/// Creates an item, or edits one. Every field is on one scrolling column, as
/// the household fills this in on a phone.
class ItemFormPage extends StatefulWidget {
  const ItemFormPage({required this.categories, this.item, super.key});

  /// The built-in categories plus every one already in use, from
  /// `availableCategories`.
  final List<String> categories;

  /// The item being edited, or null to create a new one.
  final Item? item;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  /// Identity rather than a magic string, so a member who types this same
  /// text as a category cannot collide with the sentinel.
  static final Object _addCategoryOption = Object();

  final _formKey = GlobalKey<FormState>();
  final _newCategoryController = TextEditingController();

  late final TextEditingController _nameController;
  late final TextEditingController _avgPieceWeightController;
  late final TextEditingController _dailyUsageController;
  late final TextEditingController _lowThresholdController;
  late final List<String> _categoryOptions;

  late ItemUnit _unit;
  Object? _categorySelection;
  bool _saving = false;
  DataFailure? _failure;

  bool get _addingCategory => identical(_categorySelection, _addCategoryOption);

  bool get _isEditing => widget.item != null;

  /// Only a weighed item converts pieces: see `convertToItemUnit`.
  bool get _weighed => _unit == ItemUnit.kg || _unit == ItemUnit.g;

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _nameController = TextEditingController(text: item?.name ?? '');
    _avgPieceWeightController = TextEditingController(
      text: formatDecimal(item?.avgPieceWeight),
    );
    // Non-staples use 0, which is the common case, so a new item starts there.
    _dailyUsageController = TextEditingController(
      text: item == null ? '0' : formatDecimal(item.dailyUsage),
    );
    _lowThresholdController = TextEditingController(
      text: item == null ? '' : formatDecimal(item.lowThreshold),
    );
    _unit = item?.unit ?? ItemUnit.fallback;

    final category = item?.category;
    // An edited item's own category is always offered, even if its stored
    // text never normalized to one of the derived options, so the picker
    // always has a chip to show selected.
    _categoryOptions = [
      ...widget.categories,
      if (category != null && !widget.categories.contains(category)) category,
    ];
    _categorySelection = category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newCategoryController.dispose();
    _avgPieceWeightController.dispose();
    _dailyUsageController.dispose();
    _lowThresholdController.dispose();
    super.dispose();
  }

  /// Drops a failure message once the member starts correcting the form.
  void _onFieldChanged([Object? _]) {
    if (_failure != null) {
      setState(() => _failure = null);
    }
  }

  void _onCategoryChanged(Object selection) {
    setState(() => _categorySelection = selection);
    _onFieldChanged();
  }

  String? _validateNewCategory(String? value) =>
      validateCategory(normalizeCategory(value ?? ''));

  /// The category to store: the chosen one, or the typed one folded onto an
  /// existing option when it is the same thing in different case.
  ///
  /// This is the whole defence against a catalogue growing "Baby food",
  /// "baby food" and "Baby Food" as three separate categories.
  String? _resolveCategory() {
    final selection = _categorySelection;
    if (selection is String) {
      return selection;
    }
    if (!_addingCategory) {
      return null;
    }
    final typed = normalizeCategory(_newCategoryController.text);
    if (typed.isEmpty) {
      return null;
    }
    for (final existing in _categoryOptions) {
      // Matched against the label too, so typing "Dairy & Eggs" selects the
      // built-in rather than storing its label as a new category.
      if (existing.toLowerCase() == typed.toLowerCase() ||
          categoryLabel(existing).toLowerCase() == typed.toLowerCase()) {
        return existing;
      }
    }
    return typed;
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final category = _resolveCategory();
    if (category == null) {
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
        .save(_buildItem(category))
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

  /// Deleting cannot be undone, so it is never a single unconfirmed tap.
  Future<void> _confirmDelete() async {
    final item = widget.item;
    if (item == null) {
      return;
    }

    final cubit = context.read<ItemsCubit>();
    final navigator = Navigator.of(context);

    // Asked before the confirmation, so an item a purchase points at is never
    // offered a dialog that could only end in a refusal.
    setState(() {
      _saving = true;
      _failure = null;
    });
    final blocker = await cubit.deleteBlocker(item);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _failure = blocker;
    });
    if (blocker != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(
          '${item.name} will be removed from the pantry. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });

    final result = await cubit
        .delete(item)
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

  Item _buildItem(String category) {
    final existing = widget.item;

    return Item(
      // Empty on a create, so the repository creates rather than updates.
      id: existing?.id ?? '',
      name: _nameController.text.trim(),
      unit: _unit,
      category: category,
      // Pieces only convert into a weight, so the weight is dropped along
      // with the field for an item counted in pieces or litres.
      avgPieceWeight: _weighed
          ? parseDecimal(_avgPieceWeightController.text)
          : null,
      dailyUsage: parseDecimal(_dailyUsageController.text) ?? 0,
      lowThreshold: parseDecimal(_lowThresholdController.text) ?? 0,
      // The baseline pair belongs to the stock features. An edit carries the
      // item's own values through untouched and the update never writes them;
      // a create starts at zero, and its baseline date is written by the
      // repository as a server timestamp, so the value here is ignored.
      stockAtBaseline: existing?.stockAtBaseline ?? 0,
      baselineDate: existing?.baselineDate ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: _isEditing ? 'Edit item' : 'New item',
        leading: TopBarLeading.close,
        actions: [
          // Only when editing: there is nothing to delete on a create.
          if (_isEditing)
            IconButton(
              icon: const Icon(Symbols.delete_rounded),
              tooltip: 'Delete item',
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s8,
            AppSpace.page,
            AppSpace.s24,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                // Phone stays one column; a wide window centres the form
                // instead of stretching the fields across the screen.
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      label: 'Name',
                      child: TextFormField(
                        controller: _nameController,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        validator: validateName,
                        onChanged: _onFieldChanged,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    LabeledField(
                      label: 'Measured in',
                      child: SegmentedPicker<ItemUnit>(
                        segments: [
                          for (final unit in ItemUnit.values)
                            Segment(value: unit, label: unit.label),
                        ],
                        selected: _unit,
                        onChanged: _saving
                            ? null
                            : (unit) {
                                setState(() => _unit = unit);
                                _onFieldChanged();
                              },
                      ),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    _CategoryField(
                      options: _categoryOptions,
                      selection: _categorySelection,
                      addOption: _addCategoryOption,
                      enabled: !_saving,
                      onChanged: _onCategoryChanged,
                    ),
                    if (_addingCategory) ...[
                      const SizedBox(height: AppSpace.s12),
                      LabeledField(
                        label: 'New category',
                        child: TextFormField(
                          controller: _newCategoryController,
                          enabled: !_saving,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          validator: _validateNewCategory,
                          onChanged: _onFieldChanged,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s20),
                    _StockRules(
                      unit: _unit,
                      weighed: _weighed,
                      enabled: !_saving,
                      dailyUsage: _dailyUsageController,
                      lowThreshold: _lowThresholdController,
                      avgPieceWeight: _avgPieceWeightController,
                      onChanged: _onFieldChanged,
                      onSubmitted: _save,
                    ),
                    if (_failure case final failure?) ...[
                      const SizedBox(height: AppSpace.s16),
                      FailureMessage(message: failure.message),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ActionBar(
        child: AppButton(
          label: 'Save item',
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}

/// The category chips, as a form field so an unchosen category fails
/// validation with the rest of the form.
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.options,
    required this.selection,
    required this.addOption,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> options;
  final Object? selection;
  final Object addOption;
  final bool enabled;
  final ValueChanged<Object> onChanged;

  @override
  Widget build(BuildContext context) {
    // Nothing is preselected: a category is a real choice, not something to
    // inherit from whatever sorts first.
    return FormField<Object>(
      initialValue: selection,
      validator: (value) => value == null ? validateCategory(null) : null,
      builder: (field) {
        void choose(Object value) {
          onChanged(value);
          field.didChange(value);
        }

        final error = field.errorText;
        return LabeledField(
          label: 'Category',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  for (final category in options)
                    ChoicePill(
                      label: categoryLabel(category),
                      selected: category == selection,
                      onTap: enabled ? () => choose(category) : null,
                    ),
                  ChoicePill(
                    label: 'New category',
                    icon: Symbols.add_rounded,
                    selected: identical(selection, addOption),
                    onTap: enabled ? () => choose(addOption) : null,
                  ),
                ],
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
          ),
        );
      },
    );
  }
}

/// The numbers that make an item a staple: how fast it goes, when it counts
/// as low, and what one piece weighs.
class _StockRules extends StatelessWidget {
  const _StockRules({
    required this.unit,
    required this.weighed,
    required this.enabled,
    required this.dailyUsage,
    required this.lowThreshold,
    required this.avgPieceWeight,
    required this.onChanged,
    required this.onSubmitted,
  });

  final ItemUnit unit;
  final bool weighed;
  final bool enabled;
  final TextEditingController dailyUsage;
  final TextEditingController lowThreshold;
  final TextEditingController avgPieceWeight;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stock rules', style: text.titleMedium),
          const SizedBox(height: AppSpace.s2),
          Text(
            'They drive running low and the run-out reminders.',
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpace.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Daily usage',
                  helper: '${unit.label} a day',
                  child: TextFormField(
                    controller: dailyUsage,
                    enabled: enabled,
                    keyboardType: decimal,
                    textInputAction: TextInputAction.next,
                    validator: validateRequiredAmount,
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: LabeledField(
                  label: 'Low below',
                  helper: unit.label,
                  child: TextFormField(
                    controller: lowThreshold,
                    enabled: enabled,
                    keyboardType: decimal,
                    textInputAction: weighed
                        ? TextInputAction.next
                        : TextInputAction.done,
                    validator: validateRequiredAmount,
                    onChanged: onChanged,
                    onFieldSubmitted: weighed ? null : (_) => onSubmitted(),
                  ),
                ),
              ),
            ],
          ),
          if (weighed) ...[
            const SizedBox(height: AppSpace.s16),
            LabeledField(
              label: 'Average piece weight (optional)',
              helper:
                  '${unit.label} for one piece, so “1 wedge” converts into '
                  '${unit.label}',
              child: TextFormField(
                controller: avgPieceWeight,
                enabled: enabled,
                keyboardType: decimal,
                textInputAction: TextInputAction.done,
                validator: validateOptionalWeight,
                onChanged: onChanged,
                onFieldSubmitted: (_) => onSubmitted(),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          const InfoNote(
            text: 'Leave daily usage at 0 for anything that is not a staple.',
          ),
        ],
      ),
    );
  }
}
