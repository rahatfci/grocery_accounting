import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The four destinations of the bottom navigation.
enum AppTab {
  home('Home', Symbols.home_rounded),
  pantry('Pantry', Symbols.inventory_2_rounded),
  list('List', Symbols.shopping_cart_rounded),
  spending('Spending', Symbols.bar_chart_rounded);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Which tab is showing. Any screen in the shell can move to another tab,
/// for example Home's month glance opening Spending.
class ShellCubit extends Cubit<AppTab> {
  ShellCubit() : super(AppTab.home);

  void show(AppTab tab) => emit(tab);
}
