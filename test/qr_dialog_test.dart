import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ajayfw/models/product.dart';
import 'package:ajayfw/widgets/barcode_dialog.dart';
import 'package:ajayfw/widgets/qr_dialog.dart';

void main() {
  testWidgets('QrDialog displays both Product ID and Product Name with Barcode format',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrDialog(
            productId: 'SWA-000001',
            productName: 'Nike Air Max 90',
            qrData: 'SWA-000001',
            onDownload: () async {},
            onPrint: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Barcode Generated'), findsOneWidget);
    expect(find.text('SWA-000001'), findsWidgets);
    expect(find.text('Nike Air Max 90'), findsOneWidget);
    expect(find.text('Download Barcode'), findsOneWidget);
    expect(find.text('Print Barcode'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('BarcodeDialog renders product information, Code 128 barcode, and actions',
      (WidgetTester tester) async {
    final product = Product(
      productId: 'SWA-000004',
      productName: 'Nike Slipper',
      sizeStock: {'6': 10, '7': 15, '8': 20},
      price: 250,
      quantity: 45,
      barcode: 'SWA-000004',
      qrData: 'SWA-000004',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarcodeDialog(product: product),
        ),
      ),
    );

    expect(find.text('Generated Barcode'), findsOneWidget);
    expect(find.text('Nike Slipper'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Print Sticker'), findsOneWidget);
  });
}
