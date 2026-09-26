import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/refusal_snack.dart';
import '../logic/shopping_match.dart';
import 'shopping_list_cubit.dart';

/// Adds a line of text to the shared list.
///
/// On the List tab it is an outlined field; on Home it is the last row of the
/// list's card, with no outline of its own.
class AddEntryField extends StatefulWidget {
  const AddEntryField({this.inline = false, super.key});

  final bool inline;

  @override
  State<AddEntryField> createState() => _AddEntryFieldState();
}

class _AddEntryFieldState extends State<AddEntryField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text;
    final error = validateEntryText(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    // Cleared at once: the entry shows up through the stream, from the local
    // cache, whether or not the server has seen it yet.
    _controller.clear();
    await reportRefusal(
      ScaffoldMessenger.of(context),
      context.read<ShoppingListCubit>().add(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onChanged: _onChanged,
      onSubmitted: (_) => _submit(),
      decoration: widget.inline
          ? InputDecoration(
              hintText: 'Add to the list',
              errorText: _error,
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            )
          : InputDecoration(
              hintText: 'Add to the list',
              errorText: _error,
              prefixIcon: const Icon(
                Symbols.add_rounded,
                size: 20,
                color: AppColors.brand,
              ),
            ),
    );

    if (!widget.inline) {
      return field;
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          const Icon(Symbols.add_rounded, color: AppColors.brand),
          const SizedBox(width: AppSpace.s12),
          Expanded(child: field),
        ],
      ),
    );
  }
}
