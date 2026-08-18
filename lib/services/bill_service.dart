import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/bill.dart';
import '../models/billing_cart_item.dart';
import '../models/customer.dart';
import '../models/shop_profile.dart';

/// REST API service for ajayfw.bills collection.
class BillService {
  BillService._();
  static final BillService instance = BillService._();

  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }

  // ── POST /bills ─────────────────────────────────────────────────────────────

  /// Creates a bill in MongoDB. Throws on any failure.
  /// [shopProfile] is snapshotted inside the bill so historical records are immutable.
  /// [priorOutstanding] is the customer's outstanding balance BEFORE this bill —
  /// stored in the document so reprints always show the correct financial snapshot.
  Future<Bill> createBill({
    required Customer customer,
    required List<BillingCartItem> cartItems,
    required ShopProfile shopProfile,
    String paymentStatus = 'Paid',
    double priorOutstanding = 0.0,
  }) async {
    final products = cartItems.map((item) {
      return {
        'productId': item.product.productId,
        'productName': item.product.productName,
        'size': item.selectedSize,
        'quantity': item.quantity,
        'unitPrice': item.sellingPrice,
        'lineTotal': item.lineTotal,
      };
    }).toList();

    final payload = {
      'customerId': customer.id,
      'customerName': customer.name,
      'customerShopName': customer.shopName,
      'customerMobile': customer.mobile,
      'products': products,
      'status': paymentStatus,
      'discount': 0.0,
      'tax': 0.0,
      // Customer's outstanding BEFORE this bill — snapshot for reprint accuracy
      'priorOutstanding': priorOutstanding,
      // Business profile snapshot — frozen at time of bill creation
      'businessProfile': shopProfile.toJson(),
    };

    debugPrint('[BillService] POST $_baseUrl/bills');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/bills'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('[BillService] Status: ${response.statusCode}');
    debugPrint('[BillService] Body: ${response.body}');

    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      return Bill.fromJson(data);
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception(msg);
    }
  }

  // ── GET /bills ──────────────────────────────────────────────────────────────

  Future<List<Bill>> fetchBills({String? search, String? status}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final uri = Uri.parse('$_baseUrl/bills').replace(queryParameters: params);
    debugPrint('[BillService] GET $uri');

    final response = await http
        .get(uri, headers: const {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawData = body['data'];
      if (rawData is List) {
        return rawData
            .map((e) => Bill.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return <Bill>[];
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  // ── GET /bills/<id> ──────────────────────────────────────────────────────────

  Future<Bill> fetchBillById(String invoiceNo) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/bills/$invoiceNo'),
          headers: const {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Bill.fromJson(body['data'] as Map<String, dynamic>);
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }
}
