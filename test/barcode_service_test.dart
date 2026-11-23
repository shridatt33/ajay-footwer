import 'package:flutter_test/flutter_test.dart';
import 'package:ajayfw/models/product.dart';
import 'package:ajayfw/services/barcode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BarcodeService Tests', () {
    const service = BarcodeService.instance;

    test('generateBarcode formats correctly', () {
      expect(service.generateBarcode(1), 'SWA-000001');
      expect(service.generateBarcode(42), 'SWA-000042');
      expect(service.generateBarcode(999999), 'SWA-999999');
    });

    test('buildSingleBarcodeStickerPdf generates valid PDF bytes', () async {
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

      final pdfBytes = await service.buildSingleBarcodeStickerPdf(product);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
    });

    test('buildBarcodeSheetPdf generates valid A4 sheet PDF', () async {
      final products = [
        Product(
          productId: 'SWA-000001',
          productName: 'Airgold Luna',
          sizeStock: {'6': 10},
          price: 350,
          quantity: 10,
          barcode: 'SWA-000001',
          qrData: 'SWA-000001',
          createdAt: DateTime.now(),
        ),
        Product(
          productId: 'SWA-000004',
          productName: 'Nike Slipper',
          sizeStock: {'6': 10, '7': 15, '8': 20},
          price: 250,
          quantity: 45,
          barcode: 'SWA-000004',
          qrData: 'SWA-000004',
          createdAt: DateTime.now(),
        ),
      ];

      final sheetBytes = await service.buildBarcodeSheetPdf(
        products: products,
        copiesPerProduct: 2,
      );
      expect(sheetBytes, isNotEmpty);
      expect(sheetBytes.length, greaterThan(500));
    });
  });
}
