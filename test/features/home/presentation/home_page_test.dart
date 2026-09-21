import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/home_page.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/items/presentation/item_list_page.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';

Future<void> _pumpHome(
  WidgetTester tester,
  FakeAuthRepository authRepository,
  FakeItemRepository itemRepository,
) async {
  // The providers sit above MaterialApp exactly as they do in `app.dart`: a
  // pushed route is a sibling of `home`, so anything provided inside `home`
  // is invisible to it.
  await tester.pumpWidget(
    RepositoryProvider<ItemRepository>.value(
      value: itemRepository,
      child: BlocProvider(
        create: (_) => AuthCubit(authRepository),
        child: const MaterialApp(home: HomePage(user: testUser)),
      ),
    ),
  );
}

/// The catalogue opens on an indeterminate spinner, which never stops
/// animating, so `pumpAndSettle` would time out. Pump the route transition
/// instead.
Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  // One more frame, so a popped route is unmounted and not just finished.
  await tester.pump();
}

void main() {
  late FakeAuthRepository authRepository;
  late FakeItemRepository itemRepository;

  setUp(() {
    authRepository = FakeAuthRepository();
    itemRepository = FakeItemRepository();
  });

  testWidgets('offers a way into the catalogue', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    expect(find.byTooltip('Catalogue'), findsOneWidget);
  });

  testWidgets('the catalogue action pushes the catalogue', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    await tester.tap(find.byTooltip('Catalogue'));
    await _pumpRouteTransition(tester);

    expect(find.byType(ItemListPage), findsOneWidget);
    expect(find.text('Catalogue'), findsOneWidget);
    // The pushed screen built its own cubit and started watching.
    expect(itemRepository.watchCalls, 1);
  });

  testWidgets('the catalogue can be popped back to Home', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);
    await tester.tap(find.byTooltip('Catalogue'));
    await _pumpRouteTransition(tester);

    await tester.tap(find.byTooltip('Back'));
    await _pumpRouteTransition(tester);

    expect(find.byType(ItemListPage), findsNothing);
    expect(find.byTooltip('Catalogue'), findsOneWidget);
  });

  testWidgets('signing out is still reachable', (tester) async {
    await _pumpHome(tester, authRepository, itemRepository);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    expect(authRepository.signOutCalls, 1);
  });
}
