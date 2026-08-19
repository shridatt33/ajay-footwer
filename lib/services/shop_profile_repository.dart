import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/shop_profile.dart';

/// MongoDB-backed business profile repository.
/// GET /api/business-profile → fetch saved profile
/// PUT /api/business-profile → update profile
/// MongoDB is the single source of truth.
class ShopProfileRepository {
  ShopProfileRepository._();

  static final ShopProfileRepository instance = ShopProfileRepository._();

  static String get _baseUrl {
    if (kIsWeb) return 'https://ajay-footwer.onrender.com/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://ajay-footwer.onrender.com/api';
    }
    return 'https://ajay-footwer.onrender.com/api';
  }

  /// In-memory cache — always loaded from API, never seeded with mock data.
  final ValueNotifier<ShopProfile> profile =
      ValueNotifier<ShopProfile>(ShopProfile.defaults);

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  ShopProfile get current => profile.value;

  // ── GET /business-profile ─────────────────────────────────────────────────

  Future<void> fetchProfile() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/business-profile'),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null && data.isNotEmpty) {
          profile.value = ShopProfile.fromJson(data);
        }
        // If no profile saved yet, keep defaults
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      errorMessage.value = 'Unable to load business profile: $e';
      // Keep defaults so the bill/UI doesn't break
    } finally {
      isLoading.value = false;
    }
  }

  // ── PUT /business-profile ─────────────────────────────────────────────────

  /// Updates business profile in MongoDB. Returns the saved profile on success.
  Future<ShopProfile> saveProfile(ShopProfile updated) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/business-profile'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(updated.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final saved = data != null ? ShopProfile.fromJson(data) : updated;
      profile.value = saved;
      return saved;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to save business profile: $msg');
    }
  }
}
