import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/category.dart';

/// MongoDB-backed category repository.
/// All reads/writes go through the Flask REST API → MongoDB Atlas (ajayfw.categories).
class CategoryRepository {
  CategoryRepository._();

  static final CategoryRepository instance = CategoryRepository._();

  static String get _baseUrl {
    if (kIsWeb) return 'https://ajay-footwer.onrender.com/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://ajay-footwer.onrender.com/api';
    }
    return 'https://ajay-footwer.onrender.com/api';
  }

  final ValueNotifier<List<ProductCategory>> categories =
      ValueNotifier<List<ProductCategory>>(<ProductCategory>[]);

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  List<ProductCategory> get currentCategories =>
      List<ProductCategory>.unmodifiable(categories.value);

  // ── GET /categories ─────────────────────────────────────────────────────────

  Future<void> fetchCategories() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/categories'),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawData = body['data'];
        if (rawData is List) {
          categories.value = rawData
              .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
              .toList(growable: false);
        } else {
          categories.value = <ProductCategory>[];
        }
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      errorMessage.value =
          'Unable to load categories. Please check server connection.';
    } finally {
      isLoading.value = false;
    }
  }

  // ── POST /categories ─────────────────────────────────────────────────────────

  Future<ProductCategory> addCategory(ProductCategory category) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/categories'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(category.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final saved =
          data != null ? ProductCategory.fromJson(data) : category;
      categories.value = <ProductCategory>[saved, ...categories.value];
      return saved;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to add category: $msg');
    }
  }

  // ── PUT /categories/<id> ─────────────────────────────────────────────────────

  Future<ProductCategory> updateCategory(ProductCategory category) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/categories/${category.id}'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(category.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final updated =
          data != null ? ProductCategory.fromJson(data) : category;
      categories.value = categories.value
          .map((c) => c.id == updated.id ? updated : c)
          .toList(growable: false);
      return updated;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to update category: $msg');
    }
  }

  // ── DELETE /categories/<id> ──────────────────────────────────────────────────

  Future<void> deleteCategory(String categoryId) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/categories/$categoryId'),
          headers: const {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      categories.value = categories.value
          .where((c) => c.id != categoryId)
          .toList(growable: false);
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception(msg);
    }
  }

  ProductCategory? findById(String id) {
    for (final c in categories.value) {
      if (c.id == id) return c;
    }
    return null;
  }
}
