import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../services/local_customer_repository.dart';
import '../services/payment_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Customer tab ────────────────────────────────────────────────────────────
  String _customerSearch = '';
  final TextEditingController _customerSearchCtrl = TextEditingController();

  // ── History tab ─────────────────────────────────────────────────────────────
  List<CustomerPayment> _payments = <CustomerPayment>[];
  bool _isLoadingPayments = false;
  String? _paymentsError;
  String _historySearch = '';
  final TextEditingController _historySearchCtrl = TextEditingController();

  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    LocalCustomerRepository.instance.fetchCustomers();
    _loadPaymentHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerSearchCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadPaymentHistory() async {
    setState(() {
      _isLoadingPayments = true;
      _paymentsError = null;
    });
    try {
      final payments = await PaymentService.instance.fetchPayments();
      // Newest first
      payments.sort((a, b) {
        final aTime = a.createdAt.isNotEmpty ? a.createdAt : a.paymentDate;
        final bTime = b.createdAt.isNotEmpty ? b.createdAt : b.paymentDate;
        return bTime.compareTo(aTime);
      });
      if (mounted) setState(() => _payments = payments);
    } catch (e) {
      if (mounted) {
        setState(() => _paymentsError =
            'Unable to load payment history.\n${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      LocalCustomerRepository.instance.fetchCustomers(),
      _loadPaymentHistory(),
    ]);
  }

  // ── Open Receive Payment sheet ────────────────────────────────────────────────

  Future<void> _openReceivePaymentSheet({Customer? preselected}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReceivePaymentSheet(
        preselectedCustomer: preselected,
        onSaved: _refresh,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(
          'Payments',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: _blue),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: _blue,
          unselectedLabelColor: _textSecondary,
          indicatorColor: _blue,
          indicatorWeight: 2.5,
          tabs: const [Tab(text: 'Customers'), Tab(text: 'History')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openReceivePaymentSheet(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Receive Payment',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCustomersTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  // ── Customers Tab ─────────────────────────────────────────────────────────────

  Widget _buildCustomersTab() {
    return Column(
      children: [
        _buildSearchBar(
          controller: _customerSearchCtrl,
          hint: 'Search by name or mobile...',
          onChanged: (v) => setState(() => _customerSearch = v.trim()),
          onClear: () => setState(() {
            _customerSearchCtrl.clear();
            _customerSearch = '';
          }),
        ),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: LocalCustomerRepository.instance.isLoading,
            builder: (context, loading, _) {
              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return ValueListenableBuilder<List<Customer>>(
                valueListenable: LocalCustomerRepository.instance.customers,
                builder: (context, all, _) {
                  final q = _customerSearch.toLowerCase();
                  final filtered = q.isEmpty
                      ? all
                      : all.where((c) =>
                          c.name.toLowerCase().contains(q) ||
                          c.mobile.toLowerCase().contains(q) ||
                          c.shopName.toLowerCase().contains(q)).toList();

                  final sorted = [...filtered]
                    ..sort((a, b) {
                      // Outstanding customers first
                      if (a.outstandingBalance > 0 && b.outstandingBalance <= 0) return -1;
                      if (a.outstandingBalance <= 0 && b.outstandingBalance > 0) return 1;
                      // Then highest balance first
                      return b.outstandingBalance.compareTo(a.outstandingBalance);
                    });

                  if (sorted.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.people_outline_rounded,
                      message: q.isEmpty ? 'No customers yet' : 'No results for "$q"',
                      onRefresh: _refresh,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _CustomerOutstandingCard(
                        customer: sorted[i],
                        onReceivePayment: () =>
                            _openReceivePaymentSheet(preselected: sorted[i]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return Column(
      children: [
        _buildSearchBar(
          controller: _historySearchCtrl,
          hint: 'Search by name, mobile or reference...',
          onChanged: (v) => setState(() => _historySearch = v.trim()),
          onClear: () => setState(() {
            _historySearchCtrl.clear();
            _historySearch = '';
          }),
        ),
        Expanded(child: _buildHistoryContent()),
      ],
    );
  }

  Widget _buildHistoryContent() {
    if (_isLoadingPayments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentsError != null) {
      return _ErrorState(message: _paymentsError!, onRetry: _loadPaymentHistory);
    }

    final q = _historySearch.toLowerCase();
    final filtered = q.isEmpty
        ? _payments
        : _payments.where((p) =>
            p.customerName.toLowerCase().contains(q) ||
            p.customerShopName.toLowerCase().contains(q) ||
            p.reference.toLowerCase().contains(q) ||
            p.paymentMode.toLowerCase().contains(q)).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.payments_outlined,
        message: _payments.isEmpty
            ? 'No payments recorded yet'
            : 'No results for "$_historySearch"',
        subtitle: _payments.isEmpty ? 'Tap "Receive Payment" to record one.' : null,
        onRefresh: _loadPaymentHistory,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PaymentCard(payment: filtered[i]),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────────

  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, color: _blue),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded))
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _blue, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600, color: _textDark)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer Outstanding Card ─────────────────────────────────────────────────

class _CustomerOutstandingCard extends StatelessWidget {
  const _CustomerOutstandingCard({
    required this.customer,
    required this.onReceivePayment,
  });
  final Customer customer;
  final VoidCallback onReceivePayment;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  String _initials(String name) {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    if (p.isNotEmpty && p[0].isNotEmpty) return p[0][0].toUpperCase();
    return 'C';
  }

  String _fmt(double v) => v
      .toStringAsFixed(v % 1 == 0 ? 0 : 2)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final due = customer.outstandingBalance > 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: due ? Colors.orange.shade50 : Colors.green.shade50,
              child: Text(
                _initials(customer.name),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: due ? Colors.orange.shade800 : Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(customer.mobile,
                          style: GoogleFonts.poppins(
                              fontSize: 11.5, color: _textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 13,
                        color: due ? Colors.orange.shade700 : Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        due
                            ? 'Outstanding: ₹${_fmt(customer.outstandingBalance)}'
                            : 'No Outstanding',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: due ? Colors.orange.shade800 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (due)
              FilledButton(
                onPressed: onReceivePayment,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Receive',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300, width: 0.8),
                ),
                child: Text('Paid',
                    style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Payment History Card ──────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final CustomerPayment payment;

  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  String _fmt(double v) => v
      .toStringAsFixed(v % 1 == 0 ? 0 : 2)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final timeStr = payment.displayTime;
    final dateTime = timeStr.isNotEmpty
        ? '${payment.displayDate}, $timeStr'
        : payment.displayDate;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.payments_rounded, color: Colors.green.shade700, size: 22),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer name
                  Text(payment.customerName,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                  if (payment.customerShopName.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(payment.customerShopName,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF1565C0),
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 4),

                  // Date + mode row
                  Wrap(
                    spacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(dateTime,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: _textSecondary)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(payment.paymentMode,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: _textSecondary)),
                        ],
                      ),
                    ],
                  ),

                  // Reference
                  if (payment.reference.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Ref: ${payment.reference}',
                        style: GoogleFonts.poppins(fontSize: 11, color: _textSecondary)),
                  ],

                  const SizedBox(height: 6),

                  // Previous → Remaining outstanding
                  Row(
                    children: [
                      _outstandingChip(
                        label: 'Previous',
                        value: '₹${_fmt(payment.previousOutstanding)}',
                        color: Colors.orange.shade700,
                        bg: Colors.orange.shade50,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.grey),
                      ),
                      _outstandingChip(
                        label: 'Remaining',
                        value: '₹${_fmt(payment.balanceAfter)}',
                        color: payment.balanceAfter > 0
                            ? Colors.orange.shade800
                            : Colors.green.shade700,
                        bg: payment.balanceAfter > 0
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '- ₹${_fmt(payment.amount)}',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outstandingChip({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 9, color: color.withAlpha(180))),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Receive Payment Sheet ─────────────────────────────────────────────────────

class _ReceivePaymentSheet extends StatefulWidget {
  const _ReceivePaymentSheet({
    this.preselectedCustomer,
    required this.onSaved,
  });
  final Customer? preselectedCustomer;
  final VoidCallback onSaved;

  @override
  State<_ReceivePaymentSheet> createState() => _ReceivePaymentSheetState();
}

class _ReceivePaymentSheetState extends State<_ReceivePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();

  Customer? _customer;
  String _paymentMode = 'Cash';

  /// True while the save request is in-flight — prevents double-tap.
  bool _isSaving = false;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  static const List<String> _modes = [
    'Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _customer = widget.preselectedCustomer;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v
      .toStringAsFixed(v % 1 == 0 ? 0 : 2)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  double get _enteredAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  double get _outstanding => _customer?.outstandingBalance ?? 0;
  double get _remaining => (_outstanding - _enteredAmount).clamp(0.0, double.infinity);

  Future<void> _save() async {
    // Hard guard — ignore any tap while already saving
    if (_isSaving) return;

    if (_customer == null) {
      _showSnack('Please select a customer.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final amount = _enteredAmount;
    if (amount > _outstanding + 0.001) {
      _showSnack(
        'Payment ₹${_fmt(amount)} cannot exceed outstanding ₹${_fmt(_outstanding)}.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ── Step 1: POST /api/payments ──────────────────────────────────────────
      // The backend saves the payment AND updates customer.outstandingBalance.
      await PaymentService.instance.recordPayment(
        customer: _customer!,
        amount: amount,
        paymentMode: _paymentMode,
        reference: _referenceCtrl.text.trim(),
      );

      // ── Step 2: Re-fetch customers so all screens see the authoritative balance
      await LocalCustomerRepository.instance.fetchCustomers();

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        final newBalance = (_outstanding - amount).clamp(0.0, double.infinity);
        _showSnack(
          'Payment of ₹${_fmt(amount)} received from ${_customer!.name}. '
          'Remaining: ₹${_fmt(newBalance)}',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Failed to save payment: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 4 : 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final customers = LocalCustomerRepository.instance.currentCustomers;
    // Outstanding customers first, then by balance descending
    final sorted = [...customers]
      ..sort((a, b) {
        if (a.outstandingBalance > 0 && b.outstandingBalance <= 0) return -1;
        if (a.outstandingBalance <= 0 && b.outstandingBalance > 0) return 1;
        return b.outstandingBalance.compareTo(a.outstandingBalance);
      });

    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Receive Payment',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
              const SizedBox(height: 20),

              // ── Customer ──────────────────────────────────────────────────────
              _label('Customer'),
              const SizedBox(height: 6),
              DropdownButtonFormField<Customer>(
                value: _customer,
                isExpanded: true,
                decoration: _inputDecoration(hint: 'Select customer'),
                items: sorted.map((c) => DropdownMenuItem<Customer>(
                  value: c,
                  child: Text(
                    c.outstandingBalance > 0
                        ? '${c.name}  •  Due ₹${_fmt(c.outstandingBalance)}'
                        : '${c.name}  •  No Due',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                )).toList(),
                onChanged: (c) => setState(() {
                  _customer = c;
                  _amountCtrl.clear();
                }),
              ),

              // ── Outstanding badge ──────────────────────────────────────────────
              if (_customer != null) ...[
                const SizedBox(height: 10),
                _outstandingBadge(),
              ],
              const SizedBox(height: 16),

              // ── Amount ────────────────────────────────────────────────────────
              _label('Payment Amount'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: _inputDecoration(hint: '0').copyWith(
                  prefixText: '₹  ',
                  prefixStyle: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w700, color: _textDark),
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey.shade300),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Amount must be greater than ₹0';
                  if (_customer != null && n > _outstanding + 0.001) {
                    return 'Cannot exceed outstanding ₹${_fmt(_outstanding)}';
                  }
                  return null;
                },
              ),

              // ── Remaining preview ─────────────────────────────────────────────
              if (_customer != null && _amountCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _remainingBadge(),
              ],
              const SizedBox(height: 16),

              // ── Payment Mode ──────────────────────────────────────────────────
              _label('Payment Mode'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _modes.map((mode) {
                  final sel = _paymentMode == mode;
                  return ChoiceChip(
                    label: Text(mode,
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: sel,
                    onSelected: (_) => setState(() => _paymentMode = mode),
                    selectedColor: _blue.withAlpha(30),
                    checkmarkColor: _blue,
                    side: BorderSide(color: sel ? _blue : Colors.grey.shade300),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── Reference ─────────────────────────────────────────────────────
              _label('Reference / Note (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _referenceCtrl,
                decoration: _inputDecoration(hint: 'UTR, cheque no, or note...'),
              ),
              const SizedBox(height: 24),

              // ── Save button ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  // Disable the button while saving to prevent duplicates
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Receive Payment',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.shade200,
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

  Widget _label(String text) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary));

  InputDecoration _inputDecoration({String hint = ''}) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      );

  Widget _outstandingBadge() {
    final due = _outstanding > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: due ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: due ? Colors.orange.shade300 : Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              size: 18,
              color: due ? Colors.orange.shade800 : Colors.green.shade700),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Outstanding',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: due ? Colors.orange.shade700 : Colors.green.shade600)),
              Text('₹${_fmt(_outstanding)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: due ? Colors.orange.shade800 : Colors.green.shade700,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _remainingBadge() {
    final rem = _remaining;
    final isZero = rem == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isZero ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isZero ? Colors.green.shade300 : Colors.orange.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Remaining Outstanding',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isZero ? Colors.green.shade700 : Colors.orange.shade700)),
          Text('₹${_fmt(rem)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isZero ? Colors.green.shade700 : Colors.orange.shade800,
              )),
        ],
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF627D98))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
