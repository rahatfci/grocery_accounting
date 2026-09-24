import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/receipts/presentation/receipt_uploads_cubit.dart';

import '../fake_receipts.dart';

/// Records what the cubit reports through `addError`.
class _RecordingObserver extends BlocObserver {
  final reported = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    reported.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  late FakeReceiptStore store;
  late _RecordingObserver observer;

  setUp(() {
    store = FakeReceiptStore();
    observer = _RecordingObserver();
    Bloc.observer = observer;
  });

  tearDown(() => Bloc.observer = _RecordingObserver());

  test('flushes as soon as it is created', () async {
    final cubit = ReceiptUploadsCubit(store);
    await pumpEventQueue();

    expect(store.flushes, 1);

    await cubit.close();
  });

  test('flushes again when asked', () async {
    final cubit = ReceiptUploadsCubit(store);

    await cubit.flush();

    expect(store.flushes, 2);

    await cubit.close();
  });

  test('a failing flush is reported, never thrown', () async {
    final thrown = StateError('disk');
    store.flushThrows = thrown;
    final cubit = ReceiptUploadsCubit(store);
    await pumpEventQueue();

    expect(observer.reported, [thrown]);

    await cubit.close();
  });

  test('a flush that finishes after close does nothing', () async {
    final cubit = ReceiptUploadsCubit(store);
    await cubit.close();

    await cubit.flush();

    expect(observer.reported, isEmpty);
  });
}
