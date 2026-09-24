import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../home/presentation/home_page.dart';
import '../../members/data/member_repository.dart';
import '../logic/app_user.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';
import 'sign_in_page.dart';

/// Chooses the root screen from the session. The switch is exhaustive over the
/// sealed state, so a new state cannot be added without handling it here.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // A saved session is usually restored before the gate is built, and a
    // listener only hears changes after it subscribes. Without this, a member
    // who stays signed in is never mirrored.
    if (context.read<AuthCubit>().state case AuthSignedIn(:final user)) {
      _mirrorMember(context.read<MemberRepository>(), user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      // Only the moment a session starts, so a rebuild while signed in does
      // not write the mirror document again.
      listenWhen: (previous, current) =>
          current is AuthSignedIn && previous is! AuthSignedIn,
      listener: (context, state) {
        if (state case AuthSignedIn(:final user)) {
          _mirrorMember(context.read<MemberRepository>(), user);
        }
      },
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

/// Mirrors the Auth account into `users/{uid}`, so the payer picker and the
/// reports have a member to name.
///
/// Fire and forget on purpose: the write must never block sign in or turn a
/// Firestore hiccup into a screen the member cannot get past. A failure shows
/// up later as a member missing from the picker, and the next launch or sign
/// in writes it again.
void _mirrorMember(MemberRepository repository, AppUser user) {
  unawaited(
    repository
        .upsertCurrentMember(user)
        .catchError(
          (Object _) => const Err<void, DataFailure>(UnexpectedDataFailure()),
        ),
  );
}

class _SessionUnknown extends StatelessWidget {
  const _SessionUnknown();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
