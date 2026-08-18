import 'package:flutter_test/flutter_test.dart';
import 'package:ajayfw/models/product.dart';

void main() {
  group('Product Serialization', () {
    test('Product.fromJson parses correctly', () {
      final json = {
        'productId': 'SWA-000001',
        'productName': 'Nike Air Max 90',
        'sellingPrice': 4999.0,
        'sizeStock': {'8': 10, '9': 15},
        'qrData': 'SWA-000001',
        'createdAt': '2026-08-08T12:00:00.000Z',
      };

      final product = Product.fromJson(json);

      expect(product.productId, 'SWA-000001');
      expect(product.productName, 'Nike Air Max 90');
      expect(product.price, 4999.0);
      expect(product.sizeStock, {'8': 10, '9': 15});
      expect(product.quantity, 25);
      expect(product.qrData, 'SWA-000001');
    });

    test('Product.toJson outputs correct structure', () {
      final product = Product(
        productId: 'SWA-000002',
        productName: 'Campus Sneaker',
        sizeStock: {'7': 5, '8': 8},
        price: 999.0,
        quantity: 13,
        qrData: 'SWA-000002',
        createdAt: DateTime.parse('2026-08-08T12:00:00.000Z'),
      );

      final json = product.toJson();

      expect(json['productId'], 'SWA-000002');
      expect(json['productName'], 'Campus Sneaker');
      expect(json['sellingPrice'], 999.0);
      expect(json['sizeStock'], {'7': 5, '8': 8});
      expect(json['quantity'], 13);
      expect(json['qrData'], 'SWA-000002');
    });
  });
}
