import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSummary {
  final double todaySales;
  final int todayBills;   // count of bills created today
  final int totalProducts;
  final int retailers;
  final double stockValue;
  final double todayPurchases;
  final double pendingPayments;

  const DashboardSummary({
    required this.todaySales,
    required this.todayBills,
    required this.totalProducts,
    required this.retailers,
    required this.stockValue,
    this.todayPurchases = 0.0,
    this.pendingPayments = 0.0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0.0,
      todayBills: (json['todayBills'] as num?)?.toInt() ?? 0,
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      retailers: (json['retailers'] as num?)?.toInt() ?? 0,
      stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0.0,
      todayPurchases: (json['todayPurchases'] as num?)?.toDouble() ?? 0.0,
      pendingPayments: (json['pendingPayments'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'todaySales': todaySales,
    'todayBills': todayBills,
    'totalProducts': totalProducts,
    'retailers': retailers,
    'stockValue': stockValue,
    'todayPurchases': todayPurchases,
    'pendingPayments': pendingPayments,
  };
}

/// Thrown with a human-readable message the UI can display directly.
class DashboardException implements Exception {
  final String message;
  const DashboardException(this.message);
  @override
  String toString() => message;
}

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  static const String _cacheKey = 'cached_dashboard_summary';

  static String get _baseUrl {
    if (kIsWeb) return 'https://ajay-footwer.onrender.com/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://ajay-footwer.onrender.com/api';
    }
    return 'https://ajay-footwer.onrender.com/api';
  }

  DashboardSummary? _cachedSummary;

  DashboardSummary? get cachedSummary => _cachedSummary;

  /// Loads cached summary from local storage (SharedPreferences and memory)
  Future<DashboardSummary?> loadCachedSummary() async {
    if (_cachedSummary != null) return _cachedSummary;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _cachedSummary = DashboardSummary.fromJson(map);
        return _cachedSummary;
      }
    } catch (e) {
      debugPrint('[Dashboard] Error reading cache: $e');
    }
    return null;
  }

  Future<void> _saveToCache(DashboardSummary summary) async {
    _cachedSummary = summary;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(summary.toJson()));
    } catch (e) {
      debugPrint('[Dashboard] Error saving cache: $e');
    }
  }

  /// Fetches live dashboard summary from GET /api/dashboard/summary with
  /// controlled retry logic, exponential backoff, and timeouts.
  Future<DashboardSummary> fetchSummary({int maxRetries = 2}) async {
    final url = '$_baseUrl/dashboard/summary';
    debugPrint('[Dashboard] GET $url');

    // Attempt 1: 15s timeout
    // Attempt 2: 25s timeout
    // Attempt 3: 35s timeout
    const attemptTimeouts = [
      Duration(seconds: 15),
      Duration(seconds: 25),
      Duration(seconds: 35),
    ];

    var attempts = 0;
    final totalAttempts = maxRetries + 1;

    while (attempts < totalAttempts) {
      attempts++;
      final currentTimeout = attempts <= attemptTimeouts.length
          ? attemptTimeouts[attempts - 1]
          : const Duration(seconds: 30);

      try {
        debugPrint('[Dashboard] Attempt $attempts of $totalAttempts (timeout: ${currentTimeout.inSeconds}s)');
        final response = await http
            .get(
              Uri.parse(url),
              headers: const {'Content-Type': 'application/json'},
            )
            .timeout(currentTimeout);

        debugPrint('[Dashboard] Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final data = body['data'] as Map<String, dynamic>?;
          if (data == null || data.isEmpty) {
            throw const DashboardException('No dashboard data available.');
          }
          final summary = DashboardSummary.fromJson(data);
          await _saveToCache(summary);
          return summary;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // Authentication error is non-retryable
          throw const DashboardException('Session expired. Please login again.');
        } else if (response.statusCode >= 500) {
          // Server error may be transient during restart
          if (attempts < totalAttempts) {
            await Future.delayed(Duration(milliseconds: 1000 * attempts));
            continue;
          }
          throw DashboardException('Server error (${response.statusCode}). Please retry.');
        } else {
          throw DashboardException('Unexpected response: HTTP ${response.statusCode}');
        }
      } on DashboardException {
        rethrow;
      } on TimeoutException {
        debugPrint('[Dashboard] Attempt $attempts timed out.');
        if (attempts < totalAttempts) {
          await Future.delayed(Duration(milliseconds: 1000 * attempts));
          continue;
        }
        throw const DashboardException(
          'Server response timed out. Backend may be waking up.',
        );
      } on SocketException catch (e) {
        debugPrint('[Dashboard] SocketException on attempt $attempts: $e');
        if (attempts < totalAttempts) {
          await Future.delayed(Duration(milliseconds: 1200 * attempts));
          continue;
        }
        throw const DashboardException(
          'Network unavailable. Please check your internet connection.',
        );
      } on HandshakeException catch (e) {
        debugPrint('[Dashboard] HandshakeException: $e');
        if (attempts < totalAttempts) {
          await Future.delayed(Duration(milliseconds: 1000 * attempts));
          continue;
        }
        throw const DashboardException(
          'SSL connection failed. Please check network or date/time settings.',
        );
      } on FormatException catch (e) {
        debugPrint('[Dashboard] FormatException: $e');
        throw const DashboardException('Invalid response format received from server.');
      } catch (e) {
        debugPrint('[Dashboard] Unknown error on attempt $attempts: $e');
        if (attempts < totalAttempts) {
          await Future.delayed(Duration(milliseconds: 1000 * attempts));
          continue;
        }
        throw DashboardException('Connection failed: $e');
      }
    }

    throw const DashboardException('Failed to fetch dashboard data after retries.');
  }
}
