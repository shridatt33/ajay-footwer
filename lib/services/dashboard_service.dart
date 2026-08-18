import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DashboardSummary {
  final double todaySales;
  final int todayBills;   // count of bills created today
  final int totalProducts;
  final int retailers;
  final double stockValue;

  const DashboardSummary({
    required this.todaySales,
    required this.todayBills,
    required this.totalProducts,
    required this.retailers,
    required this.stockValue,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0.0,
      todayBills: (json['todayBills'] as num?)?.toInt() ?? 0,
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      retailers: (json['retailers'] as num?)?.toInt() ?? 0,
      stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
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

  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }

  /// Fetches live dashboard summary from GET /api/dashboard/summary.
  /// Throws [DashboardException] with a specific message on any failure.
  Future<DashboardSummary> fetchSummary() async {
    final url = '$_baseUrl/dashboard/summary';
    debugPrint('[Dashboard] GET $url');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('[Dashboard] Status: ${response.statusCode}');
      debugPrint('[Dashboard] Body: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data == null || data.isEmpty) {
          throw const DashboardException('No dashboard data available');
        }
        return DashboardSummary.fromJson(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DashboardException('Session expired. Please login again.');
      } else if (response.statusCode >= 500) {
        // Try to extract backend error message
        String serverMsg = 'Server error (${response.statusCode})';
        try {
          final b = jsonDecode(response.body) as Map<String, dynamic>;
          final m = b['message']?.toString() ?? '';
          if (m.isNotEmpty) serverMsg = 'Server error: $m';
        } catch (_) {}
        throw DashboardException(serverMsg);
      } else {
        throw DashboardException(
            'Unexpected response: HTTP ${response.statusCode}');
      }
    } on DashboardException {
      rethrow;
    } on TimeoutException {
      debugPrint('[Dashboard] Request timed out for $url');
      throw const DashboardException(
          'Request timed out. Backend may be slow or unreachable.');
    } on SocketException catch (e) {
      debugPrint('[Dashboard] SocketException: $e');
      throw const DashboardException(
          'Server unavailable. Make sure the backend is running.');
    } on HandshakeException catch (e) {
      debugPrint('[Dashboard] HandshakeException: $e');
      throw const DashboardException(
          'SSL handshake failed. Check backend TLS configuration.');
    } catch (e) {
      debugPrint('[Dashboard] Unknown error: $e');
      throw DashboardException('Connection error: $e');
    }
  }
}
