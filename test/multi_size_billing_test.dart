import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ajayfw/models/billing_cart_item.dart';
import 'package:ajayfw/models/product.dart';
import 'package:ajayfw/services/local_product_repository.dart';
import 'package:ajayfw/widgets/multi_size_selection_sheet.dart';

void main() {
  final testProduct = Product(
    productId: 'SWA-000004',
    productName: 'Nike Slipper',
    categoryName: 'Slippers',
    price: 250.0,
    quantity: 45,
    sizeStock: {'6': 10, '7': 15, '8': 20},
    barcode: 'SWA-000004',
    qrData: 'SWA-000004',
    createdAt: DateTime(2026, 1, 1),
  );

  group('MultiSizeSelectionSheet Tests', () {
    testWidgets('renders all sizes with default quantity 1 for available sizes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiSizeSelectionSheet(
              product: testProduct,
              existingCartQuantities: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product details displayed
      expect(find.text('Nike Slipper'), findsOneWidget);
      expect(find.text('SWA-000004'), findsOneWidget);
      expect(find.text('All Sizes (3)'), findsOneWidget);

      // All 3 sizes visible together
      expect(find.text('Size 6'), findsOneWidget);
      expect(find.text('Size 7'), findsOneWidget);
      expect(find.text('Size 8'), findsOneWidget);

      // Default quantity is 1 for each available size -> Total 3 pairs selected
      expect(find.text('3 pairs selected'), findsOneWidget);
      expect(find.text('₹750'), findsOneWidget);
      expect(find.text('Add to Bill (3)'), findsOneWidget);
    });

    testWidgets('clearing sets all sizes to 0 and disables Add to Bill button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiSizeSelectionSheet(
              product: testProduct,
              existingCartQuantities: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Clear'
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('0 pairs selected'), findsOneWidget);
      expect(find.text('Select Size(s)'), findsOneWidget);
    });

    testWidgets('multi-size cart creation creates separate cart items and calculates total correctly', (tester) async {
      final cart = <String, BillingCartItem>{};
      String cartKey(String pid, String size) => '${pid}__$size';

      // Simulate adding sizes 6 (qty 2), 7 (qty 3), 8 (qty 1)
      final sizesToAdd = {'6': 2, '7': 3, '8': 1};

      for (final entry in sizesToAdd.entries) {
        final key = cartKey(testProduct.productId, entry.key);
        cart[key] = BillingCartItem(
          product: testProduct,
          selectedSize: entry.key,
          quantity: entry.value,
          sellingPrice: testProduct.price,
        );
      }

      // 3 separate lines in cart
      expect(cart.length, equals(3));
      expect(cart['SWA-000004__6']?.quantity, equals(2));
      expect(cart['SWA-000004__6']?.lineTotal, equals(500.0));

      expect(cart['SWA-000004__7']?.quantity, equals(3));
      expect(cart['SWA-000004__7']?.lineTotal, equals(750.0));

      expect(cart['SWA-000004__8']?.quantity, equals(1));
      expect(cart['SWA-000004__8']?.lineTotal, equals(250.0));

      // Grand total = 500 + 750 + 250 = 1500
      final grandTotal = cart.values.fold<double>(0, (sum, i) => sum + i.lineTotal);
      expect(grandTotal, equals(1500.0));

      // Stock deduction across all sizes of the same product
      final repo = LocalProductRepository.instance;
      repo.products.value = [testProduct];

      final success = repo.consumeStockForInvoice(cart.values.toList());
      expect(success, isTrue);

      final updated = repo.products.value.first;
      expect(updated.sizeStock['6'], equals(8));  // 10 - 2 = 8
      expect(updated.sizeStock['7'], equals(12)); // 15 - 3 = 12
      expect(updated.sizeStock['8'], equals(19)); // 20 - 1 = 19
      expect(updated.quantity, equals(39));       // 8 + 12 + 19 = 39
    });
  });
}
