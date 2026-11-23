import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../services/local_customer_repository.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import 'add_edit_customer_screen.dart';

enum _TransactionTab { purchases, payments }

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

  // Payment History state
  List<CustomerPayment> _payments = <CustomerPayment>[];
  bool _loadingPayments = false;

  // Active Transaction Tab
  _TransactionTab _activeTab = _TransactionTab.purchases;

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
      // Non-fatal — payment history will simply remain empty
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
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

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = _currentCustomer.outstandingBalance > 0;
    final hasMobile = _currentCustomer.mobile.trim().isNotEmpty;
    final hasAddress = _currentCustomer.address.trim().isNotEmpty;
    final hasContactInfo = hasMobile || hasAddress;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(_currentCustomer),
          tooltip: 'Back',
        ),
        title: Text(
          'Customer Details',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
            tooltip: 'Edit Customer',
            onPressed: _openEditCustomerScreen,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Customer Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.card(radius: 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            _getInitials(_currentCustomer.name),
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentCustomer.name,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_currentCustomer.shopName.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.storefront_rounded,
                                      size: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        _currentCustomer.shopName,
                                        style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Row: Call & Message / WhatsApp
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: hasMobile
                                ? () => _showActionSnackBar('Calling ${_currentCustomer.mobile}...')
                                : null,
                            icon: const Icon(Icons.call_rounded, size: 16),
                            label: Text(
                              'Call',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showActionSnackBar('Messaging ${_currentCustomer.name}...'),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: Text(
                              'WhatsApp',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF16A34A),
                              side: const BorderSide(color: Color(0xFFBBF7D0)),
                              backgroundColor: const Color(0xFFF0FDF4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Primary Action: Receive Payment
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openReceivePaymentSheet,
                        icon: const Icon(Icons.payments_rounded, size: 18),
                        label: Text(
                          hasOutstanding
                              ? 'Receive Payment  •  ₹${_formatAmount(_currentCustomer.outstandingBalance)} Due'
                              : 'Receive Payment',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Financial Summary (Two side-by-side cards with equal height)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Outstanding Amount
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: hasOutstanding ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasOutstanding ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 16,
                                  color: hasOutstanding ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Outstanding',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: hasOutstanding ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹ ${_formatAmount(_currentCustomer.outstandingBalance)}',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: hasOutstanding ? const Color(0xFF9A3412) : const Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Card 2: Total Bills
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Total Bills',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1E40AF),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_currentCustomer.totalBills} Invoices',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Compact Customer Contact Information (Mobile & Address only)
              if (hasContactInfo) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: AppDecorations.card(radius: 14),
                  child: Column(
                    children: [
                      if (hasMobile) ...[
                        _CompactInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Mobile',
                          value: _currentCustomer.mobile,
                        ),
                        if (hasAddress)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: AppColors.borderLight),
                          ),
                      ],
                      if (hasAddress)
                        _CompactInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Shop Address',
                          value: _currentCustomer.address,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 4. Combined Transaction History Section (Purchases & Payments Tabs)
              Container(
                decoration: AppDecorations.card(radius: 16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction History',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Modern Segmented Tab Bar
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              title: 'Purchases (${_currentCustomer.purchaseHistory.length})',
                              isSelected: _activeTab == _TransactionTab.purchases,
                              onTap: () => setState(() => _activeTab = _TransactionTab.purchases),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              title: 'Payments (${_payments.length})',
                              isSelected: _activeTab == _TransactionTab.payments,
                              onTap: () => setState(() => _activeTab = _TransactionTab.payments),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tab Content
                    if (_activeTab == _TransactionTab.purchases)
                      _buildPurchasesTab()
                    else
                      _buildPaymentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasesTab() {
    final purchases = _currentCustomer.purchaseHistory;

    if (purchases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No purchases recorded yet',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: purchases.length,
      separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.borderLight),
      itemBuilder: (context, index) {
        final item = purchases[index];
        final isPaid = item.status.toLowerCase() == 'paid';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPaid ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                size: 16,
                color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.invoiceNumber,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '₹ ${_formatAmount(item.amount)}',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (item.itemsSummary.isNotEmpty) ...[
                    Text(
                      item.itemsSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.date,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isPaid ? const Color(0xFF15803D) : const Color(0xFFC2410C),
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
    );
  }

  Widget _buildPaymentsTab() {
    if (_loadingPayments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_outlined, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No payments received yet',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _payments.length,
      separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.borderLight),
      itemBuilder: (context, index) {
        final p = _payments[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${_formatAmount(p.amount)}',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.paymentMode,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${p.displayDate}${p.displayTime.isNotEmpty ? ', ${p.displayTime}' : ''}',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (p.reference.isNotEmpty)
                        Text(
                          'Ref: ${p.reference}',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Balance After: ₹${_formatAmount(p.balanceAfter)}',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: p.balanceAfter > 0 ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompactInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
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

  static const List<String> _modes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
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
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
        ),
        backgroundColor: AppColors.error,
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

      // Get the freshly-updated customer object from the repository cache.
      final refreshed =
          LocalCustomerRepository.instance.getCustomerById(widget.customer.id);
      final updated = refreshed ??
          widget.customer.copyWith(
            outstandingBalance:
                (outstanding - amount).clamp(0.0, double.infinity),
          );

      final newBalance = updated.outstandingBalance;

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved(updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Payment ₹${_fmt(amount)} received. Remaining: ₹${_fmt(newBalance)}',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF16A34A),
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
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
          ),
          backgroundColor: AppColors.error,
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
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Receive Payment',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.customer.name,
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),

              // Outstanding badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                      color: Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Outstanding',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 11,
                            color: const Color(0xFFC2410C),
                          ),
                        ),
                        Text(
                          '₹${_fmt(outstanding)}',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount field
              Text(
                'Payment Amount',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  prefixText: '₹  ',
                  prefixStyle: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _remaining > 0 ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _remaining > 0 ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remaining Outstanding',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          color: _remaining > 0 ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                        ),
                      ),
                      Text(
                        '₹${_fmt(_remaining)}',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _remaining > 0 ? const Color(0xFF9A3412) : const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Payment Mode chips
              Text(
                'Payment Mode',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _modes.map((mode) {
                  final selected = _paymentMode == mode;
                  return ChoiceChip(
                    label: Text(
                      mode,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _paymentMode = mode),
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: Colors.white,
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Reference / Note
              Text(
                'Reference / Note (optional)',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  hintText: 'UTR, cheque no, or note...',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Receive Payment',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
