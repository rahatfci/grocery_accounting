import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../../core/widgets/failure_message.dart';
import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/item_unit.dart';
import '../logic/item_validation.dart';
import 'items_cubit.dart';

/// How long the form waits for the server to refuse a write before it treats
/// the write as done and closes.
///
/// With persistence on, the write is durably queued the moment it is made and
/// the catalogue reacts to it at once, so the form must not wait on the
/// server's acknowledgement: offline that never arrives. A refusal the server
/// does send comes back in milliseconds, and this window is only there to
/// catch it while the form is still on screen.
const _refusalWindow = Duration(milliseconds: 600);

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
    // text never normalized to one of the derived options, so the dropdown
    // always has a value to show.
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

  void _onCategoryChanged(Object? selection) {
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
        .timeout(_refusalWindow, onTimeout: () => const Ok(null));

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
          '${item.name} will be removed from the catalogue. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
        .timeout(_refusalWindow, onTimeout: () => const Ok(null));

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
      avgPieceWeight: parseDecimal(_avgPieceWeightController.text),
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit item' : 'New item'),
        actions: [
          // Only when editing: there is nothing to delete on a create.
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete item',
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Phone stays one column; a wide window centres the form instead
              // of stretching the fields across the screen.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      validator: validateName,
                      onChanged: _onFieldChanged,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ItemUnit>(
                      initialValue: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final unit in ItemUnit.values)
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Object>(
                      initialValue: _categorySelection,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      // Nothing is preselected: a category is a real choice,
                      // not something to inherit from whatever sorts first.
                      // No hint either, because the label already names the
                      // field and a hint reading "Choose a category" would be
                      // indistinguishable from the validator's error.
                      items: [
                        for (final category in _categoryOptions)
                          DropdownMenuItem<Object>(
                            value: category,
                            child: Text(categoryLabel(category)),
                          ),
                        DropdownMenuItem<Object>(
                          value: _addCategoryOption,
                          child: const Text('Add category'),
                        ),
                      ],
                      validator: (value) =>
                          value == null ? validateCategory(null) : null,
                      onChanged: _saving ? null : _onCategoryChanged,
                    ),
                    if (_addingCategory) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newCategoryController,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'New category',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: _validateNewCategory,
                        onChanged: _onFieldChanged,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _avgPieceWeightController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Average piece weight (optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: validateOptionalWeight,
                      onChanged: _onFieldChanged,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dailyUsageController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Daily usage',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: validateRequiredAmount,
                      onChanged: _onFieldChanged,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lowThresholdController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Low threshold',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      validator: validateRequiredAmount,
                      onChanged: _onFieldChanged,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    if (_failure case final failure?) ...[
                      const SizedBox(height: 16),
                      FailureMessage(message: failure.message),
                    ],
                    const SizedBox(height: 24),
                    _SaveButton(isSaving: _saving, onPressed: _save),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: isSaving
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Save'),
    );
  }
}
