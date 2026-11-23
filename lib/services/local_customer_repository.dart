import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/customer.dart';

/// MongoDB-backed customer repository.
/// All reads/writes go through the Flask REST API → MongoDB Atlas (ajayfw.customers).
/// There is NO local/mock data — MongoDB is the single source of truth.
class LocalCustomerRepository {
  LocalCustomerRepository._();

  static final LocalCustomerRepository instance = LocalCustomerRepository._();

  // ── Base URL (mirrors LocalProductRepository) ──────────────────────────────

  static String get _baseUrl {
    if (kIsWeb) return 'https://ajay-footwer.onrender.com/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://ajay-footwer.onrender.com/api';
    }
    return 'https://ajay-footwer.onrender.com/api';
  }

  // ── In-memory cache (populated from API, never pre-seeded) ─────────────────

  final ValueNotifier<List<Customer>> customers =
      ValueNotifier<List<Customer>>(<Customer>[]);

  // Loading / error state so UI can react
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  List<Customer> get currentCustomers =>
      List<Customer>.unmodifiable(customers.value);

  // ── GET /customers ──────────────────────────────────────────────────────────

  Future<void> fetchCustomers() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/customers'),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawData = body['data'];
        if (rawData is List) {
          customers.value = rawData
              .map((e) => Customer.fromJson(e as Map<String, dynamic>))
              .toList(growable: false);
        } else {
          customers.value = <Customer>[];
        }
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      errorMessage.value =
          'Unable to load customers. Please check server connection.\n($e)';
      // Do NOT fall back to mock data — leave the list as-is (empty on first load)
    } finally {
      isLoading.value = false;
    }
  }

  // ── POST /customers ─────────────────────────────────────────────────────────

  /// Returns the saved [Customer] on success or throws on failure.
  Future<Customer> addCustomer(Customer customer) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/customers'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(customer.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final saved = data != null ? Customer.fromJson(data) : customer;
      // Prepend to local cache
      customers.value = <Customer>[saved, ...customers.value];
      return saved;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to add customer: $msg');
    }
  }

  // ── PUT /customers/<id> ─────────────────────────────────────────────────────

  Future<Customer> updateCustomer(Customer customer) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/customers/${customer.id}'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(customer.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final updated = data != null ? Customer.fromJson(data) : customer;
      // Update local cache
      customers.value = customers.value
          .map((c) => c.id == updated.id ? updated : c)
          .toList(growable: false);
      return updated;
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to update customer: $msg');
    }
  }

  // ── DELETE /customers/<id> ──────────────────────────────────────────────────

  Future<void> deleteCustomer(String customerId) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/customers/$customerId'),
          headers: const {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      customers.value = customers.value
          .where((c) => c.id != customerId)
          .toList(growable: false);
    } else {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = body?['message'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Failed to delete customer: $msg');
    }
  }

  // ── Helpers used by BillingScreen ───────────────────────────────────────────

  Customer? getCustomerById(String id) {
    for (final c in customers.value) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Called after a bill is generated to add the invoice to the customer's
  /// purchase history in MongoDB via PUT /customers/{customerId}.
  /// [amount] should be the bill total for "Added to A/C" bills, or 0.0 for
  /// "Paid" bills — the outstanding balance is only incremented when amount > 0.
  Future<void> addInvoiceToCustomer({
    required String customerId,
    required String invoiceNumber,
    required String date,
    required double amount,
    required String status,
    required String itemsSummary,
  }) async {
    final existing = getCustomerById(customerId);
    if (existing == null) return;

    final newPurchase = CustomerPurchase(
      invoiceNumber: invoiceNumber,
      date: date,
      amount: amount,
      status: status,
      itemsSummary: itemsSummary,
    );

    // Only add to outstanding when the bill is Added to A/C (amount > 0).
    // Paid bills (amount == 0) do NOT change the outstanding balance.
    final newOutstanding = existing.outstandingBalance + amount;

    final updatedCustomer = existing.copyWith(
      purchaseHistory: <CustomerPurchase>[newPurchase, ...existing.purchaseHistory],
      totalBills: existing.totalBills + 1,
      outstandingBalance: newOutstanding,
    );

    try {
      await updateCustomer(updatedCustomer);
    } catch (_) {
      // Non-fatal: the bill was already saved to the bills collection via billing_screen
    }
  }

  // ── nextSequence kept for compatibility (not used for ID generation) ────────
  int get nextSequence => customers.value.length + 1;
}
