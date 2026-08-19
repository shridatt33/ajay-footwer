import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/customer.dart';
import '../models/customer_payment.dart';

/// REST service for the payments collection (POST/GET /api/payments).
///
/// The backend owns all balance arithmetic:
///   POST /api/payments  — saves the payment AND updates customer.outstandingBalance
///   GET  /api/payments  — returns payment history (optionally filtered by customerId)
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  static String get _baseUrl {
    if (kIsWeb) return 'https://ajay-footwer.onrender.com/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://ajay-footwer.onrender.com/api';
    }
    return 'https://ajay-footwer.onrender.com/api';
  }

  // ── POST /payments ──────────────────────────────────────────────────────────

  /// Records a payment transaction in MongoDB and updates the customer's
  /// outstanding balance on the server side.
  ///
  /// Returns the saved [CustomerPayment] on success, throws on failure.
  Future<CustomerPayment> recordPayment({
    required Customer customer,
    required double amount,
    required String paymentMode,
    String reference = '',
    String note = '',
    String? paymentDate, // ISO — defaults to server time
  }) async {
    final date = paymentDate ?? DateTime.now().toUtc().toIso8601String();

    final payload = {
      'customerId': customer.id,
      'customerName': customer.name,
      'customerShopName': customer.shopName,
      'amount': amount,
      'paymentDate': date,
      'paymentMode': paymentMode,
      'reference': reference,
      'note': note,
      // previousOutstanding and balanceAfter are computed server-side from
      // the live customer document, so no need to send them — but sending
      // them as hints keeps the payload self-documenting.
      'previousOutstanding': customer.outstandingBalance,
      'balanceAfter':
          (customer.outstandingBalance - amount).clamp(0.0, double.infinity),
    };

    debugPrint('[PaymentService] POST $_baseUrl/payments  '
        'customer=${customer.id}  amount=$amount  mode=$paymentMode');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/payments'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('[PaymentService] POST /payments → ${response.statusCode}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? payload;
      return CustomerPayment.fromJson(data);
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to record payment: $msg');
    }
  }

  // ── GET /payments ───────────────────────────────────────────────────────────

  /// Fetches payment records.
  /// Pass [customerId] to filter to a single customer's history.
  /// Pass [search] to full-text search customerName / reference.
  Future<List<CustomerPayment>> fetchPayments({
    String? customerId,
    String? search,
  }) async {
    final params = <String, String>{};
    if (customerId != null && customerId.isNotEmpty) {
      params['customerId'] = customerId;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final uri = Uri.parse('$_baseUrl/payments')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    debugPrint('[PaymentService] GET $uri');

    final response = await http
        .get(uri, headers: const {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 20));

    debugPrint('[PaymentService] GET /payments → ${response.statusCode}');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawData = body['data'];
      if (rawData is List) {
        return rawData
            .map((e) => CustomerPayment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return <CustomerPayment>[];
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('GET /payments failed: $msg');
    }
  }
}
