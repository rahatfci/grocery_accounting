import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/failure_message.dart';
import '../../auth/logic/app_user.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../../items/logic/item_validation.dart';
import '../../members/data/member_repository.dart';
import '../../members/logic/household_member.dart';
import '../../receipts/data/receipt_picker.dart';
import '../../receipts/data/receipt_reader.dart';
import '../../receipts/data/receipt_store.dart';
import '../../receipts/logic/receipt.dart';
import '../../receipts/presentation/receipt_source_sheet.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../data/purchase_repository.dart';
import '../logic/money.dart';
import '../logic/purchase_draft.dart';
import '../logic/purchase_validation.dart';
import 'purchase_line_sheet.dart';
import 'record_purchase_cubit.dart';
import 'record_purchase_state.dart';

/// How far back the date picker goes. Two years covers a forgotten receipt
/// without offering a calendar nobody wants to scroll.
const _earliestPurchaseYears = 2;

/// The review and commit screen, and the one action Home is built around.
class RecordPurchasePage extends StatelessWidget {
  const RecordPurchasePage({required this.user, this.startWith, super.key});

  final AppUser user;

  /// When set, the screen opens by picking a receipt photo from here, which
  /// is how capture on Home arrives.
  final ReceiptSource? startWith;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RecordPurchaseCubit(
        purchases: context.read<PurchaseRepository>(),
        items: context.read<ItemRepository>(),
        members: context.read<MemberRepository>(),
        shoppingList: context.read<ShoppingListRepository>(),
        receiptPicker: context.read<ReceiptPicker>(),
        receipts: context.read<ReceiptStore>(),
        receiptReader: context.read<ReceiptReader>(),
        currentUser: user,
      ),
      child: switch (startWith) {
        final source? => _PickOnOpen(
          source: source,
          child: const RecordPurchaseView(),
        ),
        null => const RecordPurchaseView(),
      },
    );
  }
}

/// The screen without its cubit, so a test can supply one.
@visibleForTesting
class RecordPurchaseView extends StatelessWidget {
  const RecordPurchaseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record a purchase')),
      body: SafeArea(
        child: BlocBuilder<RecordPurchaseCubit, RecordPurchaseState>(
          builder: (context, state) => switch (state) {
            RecordPurchaseLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            RecordPurchaseFailure(:final failure) => _LoadFailure(
              message: failure.message,
            ),
            RecordPurchaseReady(
              :final draft,
              :final items,
              :final payers,
              :final reading,
            ) =>
              _PurchaseForm(
                draft: draft,
                items: items,
                payers: payers,
                reading: reading,
              ),
          },
        ),
      ),
    );
  }
}

/// Picks the receipt as soon as the screen is up. A capture that was
/// cancelled or refused goes back to Home, since there is nothing to review.
class _PickOnOpen extends StatefulWidget {
  const _PickOnOpen({required this.source, required this.child});

  final ReceiptSource source;
  final Widget child;

  @override
  State<_PickOnOpen> createState() => _PickOnOpenState();
}

class _PickOnOpenState extends State<_PickOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final cubit = context.read<RecordPurchaseCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final outcome = await cubit.pickReceipt(widget.source);
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case ReceiptPicked(:final notice):
        if (notice != null) {
          messenger.showSnackBar(SnackBar(content: Text(notice)));
        }
      case ReceiptPickCancelled():
        navigator.pop();
      case ReceiptPickRefused(:final message):
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.read<RecordPurchaseCubit>().retry(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseForm extends StatefulWidget {
  const _PurchaseForm({
    required this.draft,
    required this.items,
    required this.payers,
    required this.reading,
  });

  final PurchaseDraft draft;
  final List<Item> items;
  final List<HouseholdMember> payers;
  final bool reading;

  @override
  State<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<_PurchaseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopController;
  late TextEditingController _totalController;

  /// Bumped when a reading fills the total in, so the field starts over as
  /// untouched instead of switching on validation for the whole form.
  int _totalFieldVersion = 0;

  bool _saving = false;

  /// Already user-facing text, from a validator or a mapped [DataFailure].
  String? _failure;

  /// The catalogue, plus the items this purchase has created so far, so a
  /// second line for a new item picks it rather than creating it twice.
  List<Item> get _pickableItems => <Item>{
    ...widget.items,
    for (final line in widget.draft.lines)
      if (line.item case final item? when line.createsItem) item,
  }.toList();

  @override
  void initState() {
    super.initState();
    _shopController = TextEditingController(text: widget.draft.shopName);
    _totalController = TextEditingController(text: widget.draft.totalText);
  }

  /// A reading can fill the total in after the field was built. What the
  /// member types arrives here unchanged, so only a real difference counts.
  ///
  /// Setting the old controller's text would count as the member typing, and
  /// the form would then flag every empty field at once. A new controller and
  /// field keep the form untouched.
  @override
  void didUpdateWidget(_PurchaseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final total = widget.draft.totalText;
    if (total != oldWidget.draft.totalText && total != _totalController.text) {
      final previous = _totalController;
      _totalController = TextEditingController(text: total);
      _totalFieldVersion++;
      // The old field still listens to it until this frame is built.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _shopController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  /// Drops a failure message once the member starts correcting the form.
  void _onFieldChanged() {
    if (_failure != null) {
      setState(() => _failure = null);
    }
  }

  Future<void> _pickDate() async {
    final cubit = context.read<RecordPurchaseCubit>();
    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(widget.draft.date),
      firstDate: DateTime(today.year - _earliestPurchaseYears),
      // A purchase cannot have happened yet, so tomorrow is not offered.
      lastDate: today,
    );

    if (picked != null) {
      cubit.setDate(picked);
    }
  }

  Future<void> _editLine({int? index}) async {
    final cubit = context.read<RecordPurchaseCubit>();
    final existing = index == null ? null : widget.draft.lines[index];

    final line = await showModalBottomSheet<PurchaseDraftLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PurchaseLineSheet(items: _pickableItems, line: existing),
    );

    if (line == null) {
      return;
    }
    if (index == null) {
      cubit.addLine(line);
    } else {
      cubit.updateLine(index, line);
    }
    _onFieldChanged();
  }

  Future<void> _attachReceipt() async {
    final cubit = context.read<RecordPurchaseCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final source = await showReceiptSourceSheet(context);
    if (source == null) {
      return;
    }
    final outcome = await cubit.pickReceipt(source);
    final message = switch (outcome) {
      ReceiptPickRefused(:final message) => message,
      ReceiptPicked(:final notice) => notice,
      ReceiptPickCancelled() => null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    final cubit = context.read<RecordPurchaseCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _failure = null;
    });

    final outcome = await cubit.commit();

    if (!mounted) {
      return;
    }
    switch (outcome) {
      case CommitSucceeded(:final receiptSkipped):
        navigator.pop();
        if (receiptSkipped != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Saved without the photo. ${receiptSkipped.message}',
              ),
            ),
          );
        }
      case CommitInvalid(:final message):
        setState(() {
          _saving = false;
          _failure = message;
        });
      case CommitFailed(:final failure):
        setState(() {
          _saving = false;
          _failure = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecordPurchaseCubit>();
    final theme = Theme.of(context);
    final draft = widget.draft;

    return Center(
      child: ConstrainedBox(
        // Phone stays one column; a wide window centres the form instead of
        // stretching it across the screen.
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              _DateField(date: draft.date, onTap: _saving ? null : _pickDate),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shopController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Shop',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: validateShopName,
                onChanged: (value) {
                  cubit.setShopName(value);
                  _onFieldChanged();
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey(_totalFieldVersion),
                controller: _totalController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Total',
                  border: OutlineInputBorder(),
                  prefixText: '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: validateTotal,
                onChanged: (value) {
                  cubit.setTotalText(value);
                  _onFieldChanged();
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: draft.paidByUserId.isEmpty
                    ? null
                    : draft.paidByUserId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Paid by',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final payer in widget.payers)
                    DropdownMenuItem(
                      value: payer.id,
                      child: Text(
                        payer.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (value) => value == null ? 'Choose who paid' : null,
                onChanged: _saving
                    ? null
                    : (payer) {
                        if (payer != null) {
                          cubit.setPaidByUserId(payer);
                          _onFieldChanged();
                        }
                      },
              ),
              const SizedBox(height: 24),
              _ReceiptSection(
                receipt: draft.receipt,
                reading: widget.reading,
                onAttach: _saving ? null : _attachReceipt,
                onRemove: _saving ? null : cubit.removeReceipt,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Lines', style: theme.textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _editLine,
                    icon: const Icon(Icons.add),
                    label: const Text('Add line'),
                  ),
                ],
              ),
              if (draft.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No lines yet. The spend is recorded either way.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else ...[
                for (final (index, line) in draft.lines.indexed)
                  _LineRow(
                    line: line,
                    onTap: _saving ? null : () => _editLine(index: index),
                    onRemove: _saving
                        ? null
                        : () {
                            cubit.removeLine(index);
                            _onFieldChanged();
                          },
                  ),
                const SizedBox(height: 8),
                _LinesTotal(draft: draft),
              ],
              const SizedBox(height: 24),
              if (_failure case final String message) ...[
                FailureMessage(message: message),
                const SizedBox(height: 16),
              ],
              _SaveButton(isSaving: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({
    required this.receipt,
    required this.reading,
    required this.onAttach,
    required this.onRemove,
  });

  final ReceiptPhoto? receipt;
  final bool reading;
  final VoidCallback? onAttach;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = receipt;
    if (photo == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onAttach,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Attach receipt photo'),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            photo.bytes,
            height: 120,
            width: 90,
            fit: BoxFit.cover,
            // Decoded at thumbnail size, not the full 2000px photo.
            cacheHeight: 360,
            semanticLabel: 'Receipt photo',
            gaplessPlayback: true,
            // A photo that will not decode still shows that one is attached.
            errorBuilder: (_, _, _) => const SizedBox(
              height: 120,
              width: 90,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receipt photo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (reading) const _ReadingProgress(),
              TextButton.icon(
                onPressed: onAttach,
                icon: const Icon(Icons.refresh),
                label: const Text('Replace'),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadingProgress extends StatelessWidget {
  const _ReadingProgress();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading receipt',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(formatPurchaseDate(date)),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.onTap,
    required this.onRemove,
  });

  final PurchaseDraftLine line;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final quantity = '${formatDecimal(line.quantity)} ${line.unit.label}';

    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      // An unmatched line saves as spend only and restocks nothing, so it must
      // stand out before it is committed by accident.
      leading: line.isMatched
          ? null
          : Icon(
              Icons.link_off,
              color: colors.error,
              semanticLabel: 'Not matched',
            ),
      title: Text(line.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      // A line that will create an item is worth seeing before it is
      // committed, because nothing else in the app will announce it.
      subtitle: line.isMatched
          ? Text(line.createsItem ? '$quantity - new item' : quantity)
          : Text(
              'Not matched - $quantity',
              style: TextStyle(color: colors.error),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatEuro(line.lineTotal)),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove line',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// The lines against the receipt total. They are allowed to differ: discounts,
/// deposits and unpriced lines are all normal, so this is a hint and never a
/// reason to refuse the purchase.
class _LinesTotal extends StatelessWidget {
  const _LinesTotal({required this.draft});

  final PurchaseDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = parseDecimal(draft.totalText);
    final lines = formatEuro(draft.linesTotal);

    return Text(
      total == null ? 'Lines $lines' : 'Lines $lines of ${formatEuro(total)}',
      style: theme.textTheme.bodySmall,
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
          : const Text('Save purchase'),
    );
  }
}
