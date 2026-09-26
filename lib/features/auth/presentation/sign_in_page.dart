import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/notes.dart';
import 'app_mark.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

/// Sign in for an account created by hand in the Firebase console. There is no
/// registration or recovery path by design.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  void _onFieldChanged(String _) =>
      context.read<AuthCubit>().failureAcknowledged();

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email';
    }
    final at = email.indexOf('@');
    if (at < 1 || at == email.length - 1 || email.contains(' ')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password' : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isSubmitting = state is AuthSubmitting;
            final failure = state is AuthSignInFailure ? state.failure : null;

            return Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s24,
                  AppSpace.s48,
                  AppSpace.s24,
                  AppSpace.s24,
                ),
                child: ConstrainedBox(
                  // Phone stays one column; a wide window centres the form
                  // instead of stretching the fields across the screen.
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: AppMark(),
                          ),
                          const SizedBox(height: AppSpace.s24),
                          Semantics(
                            header: true,
                            child: Text(
                              'Welcome back',
                              style: text.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s8),
                          Text(
                            'Sign in with the account your household set up '
                            'for you.',
                            style: text.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s32),
                          LabeledField(
                            label: 'Email',
                            child: TextFormField(
                              controller: _emailController,
                              enabled: !isSubmitting,
                              decoration: const InputDecoration(
                                hintText: 'you@example.com',
                                prefixIcon: Icon(
                                  Symbols.mail_rounded,
                                  size: 20,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              validator: _validateEmail,
                              onChanged: _onFieldChanged,
                              onFieldSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s16),
                          LabeledField(
                            label: 'Password',
                            child: TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              enabled: !isSubmitting,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Symbols.lock_rounded,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Symbols.visibility_rounded
                                        : Symbols.visibility_off_rounded,
                                    size: 20,
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              validator: _validatePassword,
                              onChanged: _onFieldChanged,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ),
                          if (failure != null) ...[
                            const SizedBox(height: AppSpace.s16),
                            FailureMessage(message: failure.message),
                          ],
                          const SizedBox(height: AppSpace.s32),
                          AppButton(
                            label: 'Sign in',
                            expand: true,
                            busy: isSubmitting,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: AppSpace.s20),
                          const InfoNote(
                            text:
                                'No account? Ask whoever runs the household to '
                                'create one. There is no sign-up or password '
                                'reset in the app.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
