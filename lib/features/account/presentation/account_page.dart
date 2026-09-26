import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/logic/app_user.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../members/presentation/household_cubit.dart';
import '../../members/presentation/household_state.dart';
import '../../receipts/presentation/receipt_uploads_cubit.dart';
import '../../reminders/presentation/run_out_reminders_cubit.dart';
import '../../reminders/presentation/run_out_reminders_state.dart';
import 'export_month_sheet.dart';
import 'reminders_sheet.dart';

/// Keep in step with `version` in pubspec.yaml.
const appVersion = '1.0.0';

/// Who is signed in, the household, what this phone does on its own, and the
/// way out. Opens from the avatar on Home.
class AccountPage extends StatelessWidget {
  const AccountPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppTopBar(title: 'Account'),
      body: BlocBuilder<HouseholdCubit, HouseholdState>(
        builder: (context, state) {
          final household = state.household;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s8,
              AppSpace.page,
              AppSpace.s24,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        radius: AppRadius.xxl,
                        child: Column(
                          children: [
                            MemberAvatar(
                              initials: household.initialsOf(user.uid),
                              tone: household.toneOf(user.uid),
                              size: AvatarSize.xLarge,
                            ),
                            const SizedBox(height: AppSpace.s8),
                            Text(
                              household.nameOf(user.uid),
                              textAlign: TextAlign.center,
                              style: text.titleLarge,
                            ),
                            const SizedBox(height: AppSpace.s8),
                            Text(
                              user.email ?? '',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s20),
                      SectionHeader(
                        title: 'Household',
                        count: household.members.length,
                      ),
                      const SizedBox(height: AppSpace.s12),
                      RowGroup(
                        children: [
                          for (final member in household.members)
                            AppRow(
                              leading: MemberAvatar(
                                initials: household.initialsOf(member.id),
                                tone: household.toneOf(member.id),
                                size: AvatarSize.medium,
                              ),
                              body: Text(
                                member.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: household.isCurrentUser(member.id)
                                  ? const StatusTag(
                                      label: 'You',
                                      tone: Tone.brand,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s12),
                      Text(
                        'Members are added by hand in the Firebase console. '
                        'There are no roles: everyone sees and edits '
                        'everything.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s20),
                      const SectionHeader(title: 'On this phone'),
                      const SizedBox(height: AppSpace.s12),
                      const RowGroup(
                        children: [
                          _RemindersRow(),
                          _UploadsRow(),
                          _ExportRow(),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s20),
                      const _SignOutButton(),
                      const SizedBox(height: AppSpace.s20),
                      Text(
                        'Grocery Accounting $appVersion · di Quattro Nero',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The Figma Row / Settings: an icon, a label, and a value on the right.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textTertiary,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppRow(
      onTap: onTap,
      leading: IconTile(
        icon: icon,
        size: 36,
        iconSize: 20,
        radius: AppRadius.sm,
      ),
      body: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodyLarge,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: text.bodyMedium?.copyWith(color: valueColor)),
          if (onTap != null) ...[
            const SizedBox(width: AppSpace.s4),
            const Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              color: AppColors.iconSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _RemindersRow extends StatelessWidget {
  const _RemindersRow();

  @override
  Widget build(BuildContext context) {
    // The web has no local notifications, so there is nothing to open.
    if (kIsWeb) {
      return const _SettingRow(
        icon: Symbols.notifications_rounded,
        label: 'Run-out reminders',
        value: 'Phone only',
      );
    }
    return BlocBuilder<RunOutRemindersCubit, RunOutRemindersState>(
      builder: (context, state) => _SettingRow(
        icon: Symbols.notifications_rounded,
        label: 'Run-out reminders',
        value: state is RunOutRemindersFailure ? 'Not set' : 'On',
        valueColor: state is RunOutRemindersFailure
            ? AppColors.warning
            : AppColors.textTertiary,
        onTap: () => showRemindersSheet(context),
      ),
    );
  }
}

class _UploadsRow extends StatelessWidget {
  const _UploadsRow();

  @override
  Widget build(BuildContext context) {
    // The web uploads a photo while the purchase is saved; nothing queues.
    if (kIsWeb) {
      return const _SettingRow(
        icon: Symbols.cloud_done_rounded,
        label: 'Receipt uploads',
        value: 'At save',
      );
    }
    return BlocBuilder<ReceiptUploadsCubit, int>(
      builder: (context, waiting) => waiting == 0
          ? const _SettingRow(
              icon: Symbols.cloud_done_rounded,
              label: 'Receipt uploads',
              value: 'All uploaded',
            )
          : _SettingRow(
              icon: Symbols.cloud_off_rounded,
              label: 'Receipt uploads',
              value: waiting == 1 ? '1 waiting' : '$waiting waiting',
              valueColor: AppColors.warning,
              onTap: () => context.read<ReceiptUploadsCubit>().flush(),
            ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow();

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      icon: Symbols.ios_share_rounded,
      label: 'Export a month',
      value: 'CSV',
      onTap: () => showExportMonthSheet(context),
    );
  }
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton();

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOut = true);
    final signedOut = await context.read<AuthCubit>().signOut();
    // A successful sign out replaces this whole screen with sign in, so only
    // a failure is left to report.
    if (!signedOut && mounted) {
      setState(() => _signingOut = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not sign out. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Sign out',
      icon: Symbols.logout_rounded,
      variant: AppButtonVariant.danger,
      expand: true,
      busy: _signingOut,
      onPressed: _signOut,
    );
  }
}
