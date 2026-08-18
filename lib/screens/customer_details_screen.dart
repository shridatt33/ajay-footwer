import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../services/local_customer_repository.dart';
import '../services/payment_service.dart';
import 'add_edit_customer_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late Customer _currentCustomer;

  // ── Payment History ──────────────────────────────────────────────────────────
  List<CustomerPayment> _payments = <CustomerPayment>[];
  bool _loadingPayments = false;

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _surfaceBg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _fetchPaymentHistory();
  }

  Future<void> _fetchPaymentHistory() async {
    setState(() => _loadingPayments = true);
    try {
      final payments = await PaymentService.instance
          .fetchPayments(customerId: _currentCustomer.id);
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _payments = payments);
    } catch (_) {
      // Non-fatal — payment history simply won't show
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  Future<void> _openReceivePaymentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _QuickReceiveSheet(
        customer: _currentCustomer,
        onSaved: (Customer updated) {
          setState(() => _currentCustomer = updated);
          _fetchPaymentHistory();
        },
      ),
    );
  }

  void _showActionSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: _primaryRoyalBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openEditCustomerScreen() async {
    final updated = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => AddEditCustomerScreen(customerToEdit: _currentCustomer),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _currentCustomer = updated;
      });
      _showActionSnackBar('Customer details updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = _currentCustomer.outstandingBalance > 0;

    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.of(context).pop(_currentCustomer),
          tooltip: 'Back',
        ),
        title: Text(
          'Customer Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: _primaryRoyalBlue),
            tooltip: 'Edit Customer',
            onPressed: _openEditCustomerScreen,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryRoyalBlue.withAlpha(12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFE8F1FB),
                      child: Text(
                        _getInitials(_currentCustomer.name),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _primaryRoyalBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentCustomer.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: _primaryRoyalBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentCustomer.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _primaryRoyalBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showActionSnackBar(
                              'Calling ${_currentCustomer.mobile}...'),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: Text(
                            'Call',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryRoyalBlue,
                            side: const BorderSide(color: _primaryRoyalBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showActionSnackBar(
                              'Messaging ${_currentCustomer.name}...'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 16),
                          label: Text(
                            'Message',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Receive Payment button — shown only when there's outstanding
                    if (_currentCustomer.outstandingBalance > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openReceivePaymentSheet,
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: Text(
                            'Receive Payment  •  ₹${_formatAmount(_currentCustomer.outstandingBalance)} Due',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Summary Metrics (Outstanding Balance & Total Bills)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasOutstanding
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFEAF5EA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasOutstanding
                              ? const Color(0xFFFFB74D)
                              : const Color(0xFFA5D6A7),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 18,
                                color: hasOutstanding
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Outstanding',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: hasOutstanding
                                      ? const Color(0xFFE65100)
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹ ${_formatAmount(_currentCustomer.outstandingBalance)}',
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: hasOutstanding
                                  ? const Color(0xFFD84315)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _primaryRoyalBlue.withAlpha(60),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                                color: _primaryRoyalBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Total Bills',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _primaryRoyalBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_currentCustomer.totalBills} Invoices',
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Contact & Business Details Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.contact_phone_rounded,
                          size: 18,
                          color: _primaryRoyalBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Contact & Business Details',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 12),

                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Mobile Number',
                      value: _currentCustomer.mobile,
                    ),
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: _currentCustomer.email.isNotEmpty
                          ? _currentCustomer.email
                          : 'Not Provided',
                    ),
                    _DetailRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'GST Number',
                      value: _currentCustomer.gstNumber.isNotEmpty
                          ? _currentCustomer.gstNumber
                          : 'N/A',
                      badge: _currentCustomer.gstNumber.isNotEmpty
                          ? 'GST VERIFIED'
                          : null,
                    ),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Shop Address',
                      value: _currentCustomer.address,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Purchase History Section
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 18,
                              color: _primaryRoyalBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Purchase History',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentCustomer.purchaseHistory.length} Records',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _primaryRoyalBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 8),

                    if (_currentCustomer.purchaseHistory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No purchase history available',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _currentCustomer.purchaseHistory.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 16, color: Color(0xFFF0F0F0)),
                        itemBuilder: (context, index) {
                          final item = _currentCustomer.purchaseHistory[index];
                          final isPaid = item.status.toLowerCase() == 'paid';

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? const Color(0xFFEAF5EA)
                                      : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPaid
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.pending_actions_rounded,
                                  size: 18,
                                  color: isPaid
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFE65100),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.invoiceNumber,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: _textDark,
                                          ),
                                        ),
                                        Text(
                                          '₹ ${_formatAmount(item.amount)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.itemsSummary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.date,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPaid
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isPaid
                                                  ? Colors.green.shade300
                                                  : Colors.orange.shade300,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            item.status.toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: isPaid
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Payment History Section
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.payments_rounded,
                              size: 18,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payment History',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_payments.length} Records',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 8),

                    if (_loadingPayments)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_payments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No payments received yet',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _textSecondary),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 16, color: Color(0xFFF0F0F0)),
                        itemBuilder: (context, index) {
                          final p = _payments[index];
                          final timeStr = _formatPaymentTime(
                              p.paymentDate.isNotEmpty
                                  ? p.paymentDate
                                  : p.createdAt);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.payments_rounded,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹${_formatAmount(p.amount)} — ${p.paymentMode}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.displayDate}${timeStr.isNotEmpty ? ', $timeStr' : ''}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade600),
                                    ),
                                    if (p.reference.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text('Ref: ${p.reference}',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: _textSecondary)),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'Balance After: ₹${_formatAmount(p.balanceAfter)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: p.balanceAfter > 0
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'C';
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatPaymentTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour;
      final m = dt.minute;
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF829AB1),
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF102A43),
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Receive Payment Sheet (used inline from CustomerDetailsScreen) ─────

class _QuickReceiveSheet extends StatefulWidget {
  const _QuickReceiveSheet({
    required this.customer,
    required this.onSaved,
  });
  final Customer customer;
  final void Function(Customer updatedCustomer) onSaved;

  @override
  State<_QuickReceiveSheet> createState() => _QuickReceiveSheetState();
}

class _QuickReceiveSheetState extends State<_QuickReceiveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();

  String _paymentMode = 'Cash';
  bool _isSaving = false;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  static const List<String> _modes = [
    'Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  String _fmt(double v) => v
      .toStringAsFixed(v % 1 == 0 ? 0 : 2)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  double get _remaining {
    final entered = double.tryParse(_amountController.text.trim()) ?? 0;
    return (widget.customer.outstandingBalance - entered)
        .clamp(0.0, double.infinity);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final outstanding = widget.customer.outstandingBalance;

    if (amount > outstanding + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Amount cannot exceed outstanding ₹${_fmt(outstanding)}.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Backend records the payment AND updates customer.outstandingBalance.
      await PaymentService.instance.recordPayment(
        customer: widget.customer,
        amount: amount,
        paymentMode: _paymentMode,
        reference: _referenceController.text.trim(),
      );

      // Re-fetch all customers so the updated balance is authoritative.
      await LocalCustomerRepository.instance.fetchCustomers();

      // Get the freshly-updated customer object from the cache.
      final refreshed =
          LocalCustomerRepository.instance.getCustomerById(widget.customer.id);
      final updated = refreshed ??
          widget.customer.copyWith(
            outstandingBalance: (outstanding - amount).clamp(0.0, double.infinity),
          );

      final newBalance = updated.outstandingBalance;

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved(updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Payment ₹${_fmt(amount)} received. '
            'Remaining: ₹${_fmt(newBalance)}',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.customer.outstandingBalance;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding:
          EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Receive Payment',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
              const SizedBox(height: 4),
              Text(widget.customer.name,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _blue)),
              const SizedBox(height: 14),

              // Outstanding
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        size: 18, color: Colors.orange.shade800),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Outstanding',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.orange.shade700)),
                        Text('₹${_fmt(outstanding)}',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade800)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              Text('Payment Amount',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  prefixText: '₹  ',
                  prefixStyle: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textDark),
                  hintText: '0',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade300),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a valid amount > 0';
                  if (n > outstanding) {
                    return 'Cannot exceed outstanding ₹${_fmt(outstanding)}';
                  }
                  return null;
                },
              ),

              // Remaining preview
              if (_amountController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _remaining > 0
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _remaining > 0
                          ? Colors.orange.shade200
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Remaining Outstanding',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _remaining > 0
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700)),
                      Text('₹${_fmt(_remaining)}',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _remaining > 0
                                ? Colors.orange.shade800
                                : Colors.green.shade700,
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Payment Mode
              Text('Payment Mode',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _modes.map((mode) {
                  final selected = _paymentMode == mode;
                  return ChoiceChip(
                    label: Text(mode,
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: selected,
                    onSelected: (_) => setState(() => _paymentMode = mode),
                    selectedColor: _blue.withAlpha(30),
                    checkmarkColor: _blue,
                    side: BorderSide(
                        color: selected ? _blue : Colors.grey.shade300),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Reference
              Text('Reference / Note (optional)',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  hintText: 'UTR, cheque no, or note...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Receive Payment',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
