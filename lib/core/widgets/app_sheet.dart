import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Opens a bottom sheet drawn the way every sheet in the design is: white,
/// 28 px top corners, a grab handle, over the 45% navy scrim.
///
/// Opens on the nearest navigator, so the sheet can read whatever the screen
/// underneath it provides.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);

/// The body of a sheet: handle, 20 px sides, 16 px between children, lifted
/// clear of the keyboard and scrollable when it does not fit.
class SheetFrame extends StatelessWidget {
  const SheetFrame({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpace.s20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Handle(),
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpace.s16),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.handle,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// A sheet's title and the line under it.
class SheetTitle extends StatelessWidget {
  const SheetTitle({required this.title, this.subtitle, super.key});

  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpace.s4),
          subtitle,
        ],
      ],
    );
  }
}
