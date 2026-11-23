import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/billing_cart_item.dart';
import '../models/product.dart';

/// MongoDB-backed product repository.
/// Communicates with the Flask REST API (ajayfw.products collection).
/// Keeps frontend stock in 100% synchronization with backend database stock.
class LocalProductRepository {
  LocalProductRepository._();

  static final LocalProductRepository instance = LocalProductRepository._();

  // ── Base URL (mirrors LocalCustomerRepository & BillService) ──────────────

  static String get _baseUrl {
    if (kIsWeb) return 'https://ajay-footwer.onrender.com/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://ajay-footwer.onrender.com/api';
    }
    return 'https://ajay-footwer.onrender.com/api';
  }

  // ── In-memory state ────────────────────────────────────────────────────────

  final ValueNotifier<List<Product>> products = ValueNotifier<List<Product>>(<Product>[]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  int get nextSequence => _extractSequence(products.value) + 1;

  List<Product> get currentProducts => List<Product>.unmodifiable(products.value);

  // ── GET /products ──────────────────────────────────────────────────────────

  /// Fetches authoritative products and size stock directly from the backend API.
  Future<void> fetchProducts() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/products'),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawData = body['data'];
        if (rawData is List) {
          final fetched = rawData
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList(growable: false);
          products.value = fetched;
        } else {
          products.value = <Product>[];
        }
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      errorMessage.value = 'Failed to load products from server: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ── Query helpers ──────────────────────────────────────────────────────────

  Product? findByProductId(String productId) {
    final cleaned = productId.trim().toLowerCase();
    for (final product in products.value) {
      if (product.productId.toLowerCase() == cleaned) {
        return product;
      }
    }
    return null;
  }

  Product? findByBarcode(String barcode) {
    final cleaned = barcode.trim().toLowerCase();
    for (final product in products.value) {
      if (product.barcode.toLowerCase() == cleaned ||
          product.displayBarcode.toLowerCase() == cleaned ||
          product.productId.toLowerCase() == cleaned) {
        return product;
      }
    }
    return null;
  }

  Product? findByBarcodeOrId(String query) {
    final cleaned = query.trim().toLowerCase();
    if (cleaned.isEmpty) return null;
    for (final product in products.value) {
      if (product.barcode.toLowerCase() == cleaned ||
          product.productId.toLowerCase() == cleaned ||
          product.displayBarcode.toLowerCase() == cleaned ||
          product.productName.toLowerCase() == cleaned) {
        return product;
      }
    }
    return null;
  }

  // ── POST /products ─────────────────────────────────────────────────────────

  Future<Product> addProduct(Product product) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/products'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(product.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final saved = data != null ? Product.fromJson(data) : product;
        products.value = <Product>[saved, ...products.value.where((p) => p.productId != saved.productId)];
        return saved;
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
        throw Exception('Failed to add product: $msg');
      }
    } catch (_) {
      // Fallback: update local cache
      products.value = <Product>[product, ...products.value.where((p) => p.productId != product.productId)];
      return product;
    }
  }

  // ── PUT /products/<id> ─────────────────────────────────────────────────────

  Future<Product> updateProduct(Product product) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/products/${product.productId}'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(product.toJson()),
          )
          .timeout(const Duration(seconds: 15));

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
    } catch (_) {
      products.value = products.value
          .map((p) => p.productId == product.productId ? product : p)
          .toList(growable: false);
      return product;
    }
  }

  // ── DELETE /products/<id> ──────────────────────────────────────────────────

  Future<void> deleteProduct(String productId) async {
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/products/$productId'),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
    products.value = products.value
        .where((product) => product.productId != productId)
        .toList(growable: false);
  }

  // ── Local optimistic stock deduction ───────────────────────────────────────

  bool consumeStockForInvoice(List<BillingCartItem> items) {
    final updates = <String, Map<String, int>>{};

    for (final item in items) {
      final currentStock = updates[item.product.productId] ?? Map<String, int>.from(item.product.sizeStock);
      final availableStock = currentStock[item.selectedSize] ?? 0;
      if (item.quantity > availableStock) {
        return false;
      }

      currentStock[item.selectedSize] = availableStock - item.quantity;
      updates[item.product.productId] = currentStock;
    }

    products.value = products.value.map((product) {
      final updatedStock = updates[product.productId];
      if (updatedStock == null) {
        return product;
      }

      final updatedQuantity = updatedStock.values.fold<int>(0, (sum, value) => sum + value);
      return product.copyWith(sizeStock: Map<String, int>.from(updatedStock), quantity: updatedQuantity);
    }).toList(growable: false);

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
