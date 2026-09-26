import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/logic/app_user.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../../items/logic/item_validation.dart';
import '../../members/data/member_repository.dart';
import '../../receipts/data/alias_repository.dart';
import '../../receipts/data/receipt_picker.dart';
import '../../receipts/data/receipt_reader.dart';
import '../../receipts/data/receipt_store.dart';
import '../../receipts/logic/receipt.dart';
import '../../receipts/presentation/receipt_photo_page.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../data/purchase_repository.dart';
import '../logic/money.dart';
import '../logic/purchase_draft.dart';
import '../logic/purchase_validation.dart';
import 'add_purchase_sheet.dart';
import 'line_sheet.dart';
import 'payer_picker.dart';
import 'purchase_detail_page.dart';
import 'purchase_saved_view.dart';
import 'receipt_strip.dart';
import 'record_purchase_cubit.dart';
import 'record_purchase_state.dart';
import 'review_line_rows.dart';

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
        aliases: context.read<AliasRepository>(),
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
    return BlocBuilder<RecordPurchaseCubit, RecordPurchaseState>(
      builder: (context, state) => switch (state) {
        RecordPurchaseLoading() => const _Frame(
          body: Center(child: CircularProgressIndicator()),
        ),
        RecordPurchaseFailure(:final failure) => _Frame(
          body: LoadFailure(
            message: failure.message,
            onRetry: context.read<RecordPurchaseCubit>().retry,
          ),
        ),
        final RecordPurchaseReady ready => _ReviewForm(state: ready),
        RecordPurchaseSaved(:final summary) => PurchaseSavedView(
          summary: summary,
          onViewPurchase: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PurchaseDetailPage(purchaseId: summary.purchaseId),
            ),
          ),
        ),
      },
    );
  }
}

/// The review screen's bar around a state with nothing to review yet.
class _Frame extends StatelessWidget {
  const _Frame({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        title: 'Review purchase',
        leading: TopBarLeading.close,
      ),
      body: SafeArea(child: body),
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
      // What reading found, or did not, is on the receipt strip.
      case ReceiptPicked():
        break;
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

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.state});

  final RecordPurchaseReady state;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopController;
  late TextEditingController _totalController;

  /// Bumped when a reading fills the total in, so the field starts over as
  /// untouched instead of switching on validation for the whole form.
  int _totalFieldVersion = 0;

  bool _saving = false;

  /// Already user-facing text, from a validator or a mapped `DataFailure`.
  String? _failure;

  PurchaseDraft get _draft => widget.state.draft;

  /// The catalogue, plus the items this purchase has created so far, so a
  /// second line for a new item picks it rather than creating it twice.
  List<Item> get _pickableItems => <Item>{
    ...widget.state.items,
    for (final line in _draft.lines)
      if (line.item case final item? when line.createsItem) item,
  }.toList();

  @override
  void initState() {
    super.initState();
    _shopController = TextEditingController(text: _draft.shopName);
    _totalController = TextEditingController(text: _draft.totalText);
  }

  /// A reading can fill the total in after the field was built. What the
  /// member types arrives here unchanged, so only a real difference counts.
  ///
  /// Setting the old controller's text would count as the member typing, and
  /// the form would then flag every empty field at once. A new controller and
  /// field keep the form untouched.
  @override
  void didUpdateWidget(_ReviewForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final total = _draft.totalText;
    if (total != oldWidget.state.draft.totalText &&
        total != _totalController.text) {
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
      initialDate: DateUtils.dateOnly(_draft.date),
      firstDate: DateTime(today.year - _earliestPurchaseYears),
      // A purchase cannot have happened yet, so tomorrow is not offered.
      lastDate: today,
    );

    if (picked != null) {
      cubit.setDate(picked);
      _onFieldChanged();
    }
  }

  Future<void> _editLine([int? index]) async {
    final cubit = context.read<RecordPurchaseCubit>();
    final existing = index == null ? null : _draft.lines[index];

    final result = await showLineSheet(
      context,
      items: _pickableItems,
      line: existing,
    );
    switch ((result, index)) {
      case (null, _) || (LineRemoved(), null):
        return;
      case (LineChosen(:final line), null):
        cubit.addLine(line);
      case (LineChosen(:final line), final index?):
        cubit.updateLine(index, line);
      case (LineRemoved(), final index?):
        cubit.removeLine(index);
    }
    _onFieldChanged();
  }

  void _removeLine(int index) {
    context.read<RecordPurchaseCubit>().removeLine(index);
    _onFieldChanged();
  }

  Future<void> _pickReceipt() async {
    final cubit = context.read<RecordPurchaseCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final source = switch (await showAddPurchaseSheet(
      context,
      photoOnly: true,
    )) {
      PurchaseStart.camera => ReceiptSource.camera,
      PurchaseStart.gallery => ReceiptSource.gallery,
      PurchaseStart.manual || null => null,
    };
    if (source == null) {
      return;
    }
    // What reading found, or did not, is on the receipt strip.
    if (await cubit.pickReceipt(source) case ReceiptPickRefused(
      :final message,
    )) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openPhoto(ReceiptPhoto photo) {
    final cubit = context.read<RecordPurchaseCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptPhotoPage(
          bytes: photo.bytes,
          onRemove: _saving ? null : cubit.removeReceipt,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    final cubit = context.read<RecordPurchaseCubit>();
    setState(() {
      _saving = true;
      _failure = null;
    });

    // On success the cubit moves on to what the save did, and this form goes.
    final message = switch (await cubit.commit()) {
      CommitSucceeded() => null,
      CommitInvalid(:final message) => message,
      CommitFailed(:final failure) => failure.message,
    };
    if (mounted && message != null) {
      setState(() {
        _saving = false;
        _failure = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final draft = _draft;
    final reading = state.reading;
    final total = parseDecimal(draft.totalText);
    final failure = _failure;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Review purchase',
        leading: TopBarLeading.close,
        actions: [
          if (draft.receipt case final photo?)
            IconButton(
              icon: const Icon(Symbols.image_rounded),
              tooltip: 'View receipt photo',
              onPressed: () => _openPhoto(photo),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            // A wide window centres the review rather than stretching it.
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
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
                  if (reading) ...[
                    ReadingCard(photo: draft.receipt),
                    const SizedBox(height: AppSpace.s20),
                  ],
                  _DetailsCard(
                    state: state,
                    saving: _saving,
                    shopController: _shopController,
                    totalController: _totalController,
                    totalFieldKey: ValueKey(_totalFieldVersion),
                    onFieldChanged: _onFieldChanged,
                    onPickDate: _pickDate,
                    onPickReceipt: _pickReceipt,
                  ),
                  const SizedBox(height: AppSpace.s20),
                  if (reading) ...[
                    const SectionHeader(title: 'Lines'),
                    const SizedBox(height: AppSpace.s12),
                    const LinesSkeleton(),
                  ] else
                    ..._lineSections(draft),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                AppSpace.s8,
                AppSpace.page,
                AppSpace.s8,
              ),
              child: FailureMessage(message: failure),
            ),
          ActionBar(
            summaryLabel: 'Total',
            summaryValue: reading || total == null ? '...' : formatEuro(total),
            child: AppButton(
              label: 'Save purchase',
              expand: true,
              busy: _saving,
              onPressed: reading ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  /// Unmatched lines first, since they are the ones that need the member,
  /// then everything that restocks, then the lines against the total.
  List<Widget> _lineSections(PurchaseDraft draft) {
    final editable = !_saving;
    final unmatched = [
      for (final (index, line) in draft.lines.indexed)
        if (!line.isMatched) (index, line),
    ];
    final matched = [
      for (final (index, line) in draft.lines.indexed)
        if (line.isMatched) (index, line),
    ];
    final total = parseDecimal(draft.totalText);
    final text = Theme.of(context).textTheme;

    return [
      if (unmatched.isNotEmpty) ...[
        SectionHeader(title: 'To match', count: unmatched.length),
        const SizedBox(height: AppSpace.s8),
        Text(
          'Unmatched lines are saved as spend only and restock nothing. '
          'Match them once and the app remembers.',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.s8),
        RowGroup(
          children: [
            for (final (index, line) in unmatched)
              RemovableLine(
                line: line,
                onRemove: editable ? () => _removeLine(index) : null,
                child: UnmatchedLineRow(
                  line: line,
                  onMatch: editable ? () => _editLine(index) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
      ],
      SectionHeader(
        title: unmatched.isEmpty ? 'Lines' : 'Matched',
        count: matched.isEmpty ? null : matched.length,
        actionLabel: 'Add line',
        onAction: editable ? _editLine : null,
      ),
      const SizedBox(height: AppSpace.s12),
      RowGroup(
        children: [
          if (matched.isEmpty)
            NoteRow(
              icon: Symbols.receipt_long_rounded,
              text: unmatched.isEmpty
                  ? 'No lines yet. The spend is recorded either way.'
                  : 'Nothing matched yet. Matched lines restock the pantry.',
            ),
          for (final (index, line) in matched)
            RemovableLine(
              line: line,
              onRemove: editable ? () => _removeLine(index) : null,
              child: MatchedLineRow(
                line: line,
                onTap: editable ? () => _editLine(index) : null,
              ),
            ),
        ],
      ),
      if (draft.lines.isNotEmpty && total != null && total > 0) ...[
        const SizedBox(height: AppSpace.s20),
        LinesTotalCard(linesTotal: draft.linesTotal, total: total),
      ],
    ];
  }
}

/// Where the purchase was, when, for how much and who paid, with the receipt
/// strip on top. While the photo is read, the fields it fills stand in grey.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.state,
    required this.saving,
    required this.shopController,
    required this.totalController,
    required this.totalFieldKey,
    required this.onFieldChanged,
    required this.onPickDate,
    required this.onPickReceipt,
  });

  final RecordPurchaseReady state;
  final bool saving;
  final TextEditingController shopController;
  final TextEditingController totalController;
  final Key totalFieldKey;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickReceipt;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecordPurchaseCubit>();
    final draft = state.draft;
    final reading = state.reading;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!reading) ...[
            ReceiptStrip(
              photo: draft.receipt,
              readResult: state.readResult,
              readFailed: state.readFailed,
              onPick: saving ? null : onPickReceipt,
            ),
            const SizedBox(height: AppSpace.s16),
            const Divider(height: 1),
            const SizedBox(height: AppSpace.s16),
          ],
          if (reading)
            const _FieldSkeleton()
          else
            LabeledField(
              label: 'Shop',
              child: TextFormField(
                controller: shopController,
                enabled: !saving,
                decoration: const InputDecoration(
                  hintText: 'Where you shopped',
                  prefixIcon: Icon(Symbols.storefront_rounded, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: validateShopName,
                onChanged: (value) {
                  cubit.setShopName(value);
                  onFieldChanged();
                },
              ),
            ),
          const SizedBox(height: AppSpace.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: reading
                    ? const _FieldSkeleton()
                    : LabeledField(
                        label: 'Date',
                        child: _DateField(
                          date: draft.date,
                          onTap: saving ? null : onPickDate,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: reading
                    ? const _FieldSkeleton()
                    : LabeledField(
                        label: 'Total',
                        child: TextFormField(
                          key: totalFieldKey,
                          controller: totalController,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            prefixText: '€ ',
                            errorMaxLines: 3,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          validator: validateTotal,
                          onChanged: (value) {
                            cubit.setTotalText(value);
                            onFieldChanged();
                          },
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          PayerPicker(
            household: state.household,
            selected: draft.paidByUserId,
            onChanged: saving
                ? null
                : (payer) {
                    cubit.setPaidByUserId(payer);
                    onFieldChanged();
                  },
          ),
        ],
      ),
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  const _FieldSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SkeletonBox(width: 56, height: 10),
          ),
          SizedBox(height: AppSpace.s6),
          SkeletonBox(height: 52, radius: AppRadius.md),
        ],
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
    return Semantics(
      button: true,
      hint: 'Change the date',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InputDecorator(
          // The text fields' own style, so this field is exactly as tall as
          // the total beside it.
          baseStyle: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            enabled: onTap != null,
            suffixIcon: const Icon(Symbols.calendar_today_rounded, size: 20),
          ),
          child: Text(
            formatPurchaseDate(date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
