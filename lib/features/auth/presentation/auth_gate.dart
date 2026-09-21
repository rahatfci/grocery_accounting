import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../home/presentation/home_page.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';
import 'sign_in_page.dart';

/// Chooses the root screen from the session. The switch is exhaustive over the
/// sealed state, so a new state cannot be added without handling it here.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => switch (state) {
        AuthInitial() => const _SessionUnknown(),
        AuthSignedOut() ||
        AuthSubmitting() ||
        AuthSignInFailure() => const SignInPage(),
        AuthSignedIn(:final user) => HomePage(user: user),
      },
    );
  }
}

class _SessionUnknown extends StatelessWidget {
  const _SessionUnknown();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
