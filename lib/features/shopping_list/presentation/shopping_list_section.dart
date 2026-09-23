import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/refusal_window.dart';
import '../../../core/result.dart';
import '../logic/shopping_entry.dart';
import '../logic/shopping_match.dart';
import 'shopping_list_cubit.dart';
import 'shopping_list_state.dart';

/// Home's shopping list, as a sliver so a long list scrolls with the rest of
/// Home instead of overflowing it.
class ShoppingListSection extends StatelessWidget {
  const ShoppingListSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: _Heading()),
        const SliverToBoxAdapter(child: _AddEntryField()),
        BlocBuilder<ShoppingListCubit, ShoppingListState>(
          builder: (context, state) => switch (state) {
            ShoppingListLoading() => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            ShoppingListEmpty() => const SliverToBoxAdapter(
              child: _Note(text: 'The list is empty'),
            ),
            ShoppingListFailure(:final failure) => SliverToBoxAdapter(
              child: _Failure(message: failure.message),
            ),
            ShoppingListLoaded(:final entries) => SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) => _EntryRow(
                key: ValueKey(entries[index].id),
                entry: entries[index],
              ),
            ),
          },
        ),
      ],
    );
  }
}

/// Shows a refused write. A write that is still pending when the window
/// closes is queued offline, and the stream already shows it.
Future<void> _reportRefusal(
  ScaffoldMessengerState messenger,
  Future<Result<void, DataFailure>> write,
) async {
  final result = await write.timeout(
    refusalWindow,
    onTimeout: () => const Ok(null),
  );
  if (result case Err(:final error)) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          'Shopping list',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _AddEntryField extends StatefulWidget {
  const _AddEntryField();

  @override
  State<_AddEntryField> createState() => _AddEntryFieldState();
}

class _AddEntryFieldState extends State<_AddEntryField> {
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
    await _reportRefusal(
      ScaffoldMessenger.of(context),
      context.read<ShoppingListCubit>().add(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _controller,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onChanged: _onChanged,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Add to the list',
          errorText: _error,
          suffixIcon: IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add',
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.read<ShoppingListCubit>().retry(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, super.key});

  final ShoppingEntry entry;

  @override
  Widget build(BuildContext context) {
    // Only the checkbox removes the entry, not the whole row: there is no
    // undo, so a stray tap while scrolling must not delete anything.
    return ListTile(
      leading: Checkbox(
        value: false,
        semanticLabel: 'Got ${entry.text}',
        onChanged: (_) => _reportRefusal(
          ScaffoldMessenger.of(context),
          context.read<ShoppingListCubit>().remove(entry),
        ),
      ),
      title: Text(entry.text, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
