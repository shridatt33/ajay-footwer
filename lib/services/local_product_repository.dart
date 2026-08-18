import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/billing_cart_item.dart';
import '../models/product.dart';

class LocalProductRepository {
  LocalProductRepository._();

  static final LocalProductRepository instance = LocalProductRepository._();

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }

  final ValueNotifier<List<Product>> products =
      ValueNotifier<List<Product>>(<Product>[]);

  int get nextSequence => _extractSequence(products.value) + 1;

  List<Product> get currentProducts =>
      List<Product>.unmodifiable(products.value);

  Product? findByProductId(String productId) {
    for (final product in products.value) {
      if (product.productId.toLowerCase() == productId.toLowerCase()) {
        return product;
      }
    }
    return null;
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: const {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawData = body['data'];
        if (rawData is List) {
          final fetched = rawData
              .map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList(growable: false);
          products.value = fetched;
          return fetched;
        }
        products.value = <Product>[];
        return <Product>[];
      } else {
        throw Exception(
          'Failed to load products from server (HTTP ${response.statusCode}).',
        );
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Could not connect to backend server: $e');
    }
  }

  Future<Product> addProduct(Product product) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(product.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final newProduct = data != null ? Product.fromJson(data) : product;

      products.value = <Product>[newProduct, ...products.value];
      return newProduct;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to add product: $msg');
    }
  }

  Future<Product> updateProduct(Product product) async {
    final response = await http.put(
      Uri.parse('$baseUrl/products/${product.productId}'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(product.toJson()),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final updated = data != null ? Product.fromJson(data) : product;

      products.value = products.value
          .map((p) => p.productId == updated.productId ? updated : p)
          .toList(growable: false);
      return updated;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to update product: $msg');
    }
  }

  Future<void> deleteProduct(String productId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/products/$productId'),
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      products.value = products.value
          .where((product) => product.productId != productId)
          .toList(growable: false);
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to delete product: $msg');
    }
  }

  Future<bool> consumeStockForInvoice(List<BillingCartItem> items) async {
    final updates = <String, Map<String, int>>{};

    for (final item in items) {
      final currentStock = updates[item.product.productId] ??
          Map<String, int>.from(item.product.sizeStock);
      final availableStock = currentStock[item.selectedSize] ?? 0;
      if (item.quantity > availableStock) {
        return false;
      }

      currentStock[item.selectedSize] = availableStock - item.quantity;
      updates[item.product.productId] = currentStock;
    }

    final updatedProducts = products.value.map((product) {
      final updatedStock = updates[product.productId];
      if (updatedStock == null) {
        return product;
      }

      final updatedQuantity =
          updatedStock.values.fold<int>(0, (sum, value) => sum + value);
      final updatedProduct = product.copyWith(
        sizeStock: Map<String, int>.from(updatedStock),
        quantity: updatedQuantity,
      );

      updateProduct(updatedProduct).catchError((_) => updatedProduct);

      return updatedProduct;
    }).toList(growable: false);

    products.value = updatedProducts;
    return true;
  }

  int _extractSequence(List<Product> currentProducts) {
    var maxSequence = 0;
    for (final product in currentProducts) {
      final parts = product.productId.split('-');
      if (parts.length == 2) {
        final sequence = int.tryParse(parts[1]) ?? 0;
        if (sequence > maxSequence) {
          maxSequence = sequence;
        }
      }
    }
    return maxSequence;
  }
}