import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../items/logic/running_low.dart';
import '../../items/logic/stock.dart';
import 'running_low_cubit.dart';
import 'running_low_state.dart';

/// Home's running low list, as a sliver so a long list scrolls with the rest
/// of Home instead of overflowing it.
class RunningLowSection extends StatelessWidget {
  const RunningLowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: _Heading()),
        BlocBuilder<RunningLowCubit, RunningLowState>(
          builder: (context, state) => switch (state) {
            RunningLowLoading() => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            RunningLowNone() => const SliverToBoxAdapter(
              child: _Note(text: 'Nothing is running low'),
            ),
            RunningLowFailure(:final failure) => SliverToBoxAdapter(
              child: _Failure(message: failure.message),
            ),
            RunningLowLoaded(:final items) => SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _LowRow(
                key: ValueKey(items[index].item.id),
                low: items[index],
              ),
            ),
          },
        ),
      ],
    );
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
          'Running low',
          style: Theme.of(context).textTheme.titleMedium,
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
            onPressed: () => context.read<RunningLowCubit>().retry(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _LowRow extends StatelessWidget {
  const _LowRow({required this.low, super.key});

  final LowStockItem low;

  @override
  Widget build(BuildContext context) {
    final item = low.item;

    return ListTile(
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Below ${formatStock(item.lowThreshold, item.unit)}'),
      trailing: Text(formatStock(low.stock, item.unit)),
    );
  }
}
