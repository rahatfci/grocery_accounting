import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sends errors a bloc or cubit reports through `addError` to Flutter's error
/// handling. The default observer ignores them, so without this a caught
/// failure that is mapped to a user message leaves no trace.
class ErrorReportingBlocObserver extends BlocObserver {
  const ErrorReportingBlocObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'state management',
        context: ErrorDescription('in ${bloc.runtimeType}'),
      ),
    );
  }
}
