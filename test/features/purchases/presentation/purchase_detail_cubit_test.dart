import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_detail_cubit.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_detail_state.dart';

import '../../receipts/fake_receipts.dart';
import '../fake_purchase_repository.dart';

void main() {
  late FakePurchaseRepository purchases;
  late FakeReceiptStore receipts;

  setUp(() {
    purchases = FakePurchaseRepository();
    receipts = FakeReceiptStore();
  });

  PurchaseDetailCubit build() {
    final cubit = PurchaseDetailCubit(
      purchases: purchases,
      receipts: receipts,
      purchaseId: 'p1',
    );
    addTearDown(cubit.close);
    return cubit;
  }

  PurchasePhoto photoOf(PurchaseDetailCubit cubit) =>
      (cubit.state as PurchaseDetailLoaded).photo;

  test('shows the purchase, with no photo when it has none', () async {
    final purchase = testPurchase();
    purchases.purchasesById = {'p1': purchase};

    final cubit = build();
    await pumpEventQueue();

    expect(cubit.state, isA<PurchaseDetailLoaded>());
    expect((cubit.state as PurchaseDetailLoaded).purchase, purchase);
    expect(photoOf(cubit), isA<NoPurchasePhoto>());
    expect(receipts.reads, isEmpty);
  });

  test('loads the photo the purchase points at', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    receipts.photos['p1'] = bytes;
    receipts.readGate = Completer<void>();
    purchases.purchasesById = {
      'p1': testPurchase(receiptImagePath: 'receipts/p1'),
    };

    final cubit = build();
    await pumpEventQueue();
    expect(photoOf(cubit), isA<PurchasePhotoLoading>());

    receipts.readGate?.complete();
    await pumpEventQueue();

    expect(receipts.reads, ['p1']);
    expect((photoOf(cubit) as PurchasePhotoLoaded).bytes, same(bytes));
  });

  test('reads the photo once, however often the purchase reports', () async {
    receipts.photos['p1'] = Uint8List.fromList([1]);
    purchases.purchasesById = {
      'p1': testPurchase(receiptImagePath: 'receipts/p1'),
    };

    build();
    await pumpEventQueue();
    purchases.emitPurchase(
      testPurchase(receiptImagePath: 'receipts/p1', total: 30),
    );
    await pumpEventQueue();

    expect(receipts.reads, ['p1']);
  });

  test('reads the photo when the path arrives later, as on the web', () async {
    receipts.photos['p1'] = Uint8List.fromList([1]);
    purchases.purchasesById = {'p1': testPurchase()};

    final cubit = build();
    await pumpEventQueue();
    expect(photoOf(cubit), isA<NoPurchasePhoto>());

    purchases.emitPurchase(testPurchase(receiptImagePath: 'receipts/p1'));
    await pumpEventQueue();

    expect(photoOf(cubit), isA<PurchasePhotoLoaded>());
  });

  test(
    'a photo that cannot be read says why, and can be asked for again',
    () async {
      receipts.readFailure = const ConnectionUnavailable();
      purchases.purchasesById = {
        'p1': testPurchase(receiptImagePath: 'receipts/p1'),
      };

      final cubit = build();
      await pumpEventQueue();

      expect(
        (photoOf(cubit) as PurchasePhotoFailed).message,
        const ConnectionUnavailable().message,
      );

      receipts.photos['p1'] = Uint8List.fromList([1]);
      cubit.retryPhoto();
      await pumpEventQueue();

      expect(photoOf(cubit), isA<PurchasePhotoLoaded>());
      expect(receipts.reads, ['p1', 'p1']);
    },
  );

  test('a purchase that is gone says so', () async {
    final cubit = build();
    await pumpEventQueue();

    expect(cubit.state, const PurchaseDetailMissing());
  });

  test('a failed watch shows the failure, and retry listens again', () async {
    purchases.holdPurchase = true;
    final cubit = build();

    purchases.emitPurchaseError(const PermissionDenied());
    await pumpEventQueue();
    expect(cubit.state, const PurchaseDetailFailure(PermissionDenied()));

    cubit.retry();
    expect(cubit.state, const PurchaseDetailLoading());
    expect(purchases.purchaseControllers, hasLength(2));
  });
}
