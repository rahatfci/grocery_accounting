import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/error_reporting_bloc_observer.dart';

class _ProbeCubit extends Cubit<int> {
  _ProbeCubit() : super(0);

  void fail(Object error, StackTrace stackTrace) => addError(error, stackTrace);
}

void main() {
  test('a reported bloc error reaches Flutter error handling', () async {
    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    final previousObserver = Bloc.observer;
    FlutterError.onError = reported.add;
    Bloc.observer = const ErrorReportingBlocObserver();
    addTearDown(() {
      FlutterError.onError = previousOnError;
      Bloc.observer = previousObserver;
    });

    final cubit = _ProbeCubit();
    final error = StateError('boom');
    final stackTrace = StackTrace.current;
    cubit.fail(error, stackTrace);

    expect(reported, hasLength(1));
    expect(reported.single.exception, same(error));
    expect(reported.single.stack, same(stackTrace));
    expect(reported.single.library, 'state management');
    expect(reported.single.context.toString(), contains('_ProbeCubit'));

    await cubit.close();
  });
}
