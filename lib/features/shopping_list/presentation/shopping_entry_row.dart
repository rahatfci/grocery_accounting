import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/refusal_snack.dart';
import '../logic/shopping_entry.dart';
import 'shopping_list_cubit.dart';

/// How long a ticked entry stays on screen, ticked, before it goes.
const tickedEntryDelay = Duration(milliseconds: 700);

/// One entry with the checkbox that removes it.
///
/// A tick shows for a moment before the entry goes, as the design has it, and
/// a second tap in that moment keeps it. Only the checkbox removes: there is
/// no undo, so a stray tap on the text while scrolling must do nothing.
class ShoppingEntryRow extends StatefulWidget {
  const ShoppingEntryRow({
    required this.entry,
    required this.meta,
    this.tickDelay = tickedEntryDelay,
    super.key,
  });

  final ShoppingEntry entry;

  /// Who added it and when, already worded.
  final String meta;

  final Duration tickDelay;

  @override
  State<ShoppingEntryRow> createState() => _ShoppingEntryRowState();
}

class _ShoppingEntryRowState extends State<ShoppingEntryRow> {
  Timer? _pending;
  VoidCallback? _removal;

  void _onChanged(bool ticked) {
    if (!ticked) {
      _pending?.cancel();
      _pending = null;
      _removal = null;
      setState(() {});
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ShoppingListCubit>();
    final entry = widget.entry;
    // Captured now, so the removal still runs if this row is gone by then.
    _removal = () => reportRefusal(messenger, cubit.remove(entry));
    _pending = Timer(widget.tickDelay, _remove);
    setState(() {});
  }

  void _remove() {
    final removal = _removal;
    _pending = null;
    _removal = null;
    removal?.call();
  }

  @override
  void dispose() {
    // A ticked entry still goes when its row does, for example when the
    // member leaves the screen inside the moment.
    if (_pending?.isActive ?? false) {
      _pending?.cancel();
      _remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ticked = _removal != null;
    final color = ticked ? AppColors.textTertiary : AppColors.textPrimary;

    // The checkbox's 40 px touch target already holds 8 px of the design's
    // 16 px margin and 12 px gap around its 24 px box.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          AppCheckbox(
            checked: ticked,
            semanticLabel: 'Got ${widget.entry.text}',
            onChanged: _onChanged,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: RowText(
              title: widget.entry.text,
              subtitle: widget.meta,
              titleStyle: text.bodyLarge?.copyWith(color: color),
              subtitleStyle: text.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
