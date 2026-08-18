import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bill_grouping.dart';
import '../models/billing_cart_item.dart';
import '../models/customer.dart';
import '../screens/bill_preview_screen.dart';

/// Possible payment status choices the user can select in the dialog.
enum InvoicePaymentStatus { addToAccount, paid }

/// Callback invoked when the user taps Done with a confirmed payment status.
/// [status] is either 'Added to A/C' or 'Paid'.
typedef InvoiceDoneCallback = Future<void> Function(String status);

class BillingInvoiceDialog extends StatefulWidget {
  final Customer customer;
  final String invoiceNumber;
  /// Human-readable display date e.g. "18 Aug 2026".
  final String invoiceDate;
  /// ISO timestamp from the saved bill (used to show time on the print screen).
  final String invoiceCreatedAt;
  final List<BillingCartItem> items;
  final double grandTotal;

  /// Called when user taps Done with a valid selection. Receives 'Added to A/C'
  /// or 'Paid'. The widget shows a loading indicator while the future runs.
  final InvoiceDoneCallback onDone;

  /// Pre-bill outstanding balance (before any update).
  final double priorOutstanding;

  const BillingInvoiceDialog({
    super.key,
    required this.customer,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.invoiceCreatedAt,
    required this.items,
    required this.grandTotal,
    required this.onDone,
    required this.priorOutstanding,
  });

  @override
  State<BillingInvoiceDialog> createState() => _BillingInvoiceDialogState();
}

class _BillingInvoiceDialogState extends State<BillingInvoiceDialog> {
  InvoicePaymentStatus? _selected;
  bool _isSaving = false;
  bool _showValidationError = false;

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(amount % 1 == 0 ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Future<void> _handleDone() async {
    if (_selected == null) {
      setState(() => _showValidationError = true);
      return;
    }
    setState(() {
      _isSaving = true;
      _showValidationError = false;
    });

    final statusStr = _selected == InvoicePaymentStatus.paid
        ? 'Paid'
        : 'Added to A/C';

    try {
      await widget.onDone(statusStr);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save: ${e.toString().replaceAll('Exception: ', '')}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPaymentOption({
    required InvoicePaymentStatus value,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
    required Color activeBorder,
  }) {
    final isSelected = _selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: _isSaving
            ? null
            : () => setState(() {
                  _selected = value;
                  _showValidationError = false;
                }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeBorder : Colors.grey.shade300,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withAlpha(24)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isSelected ? activeColor.withAlpha(180) : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 6),
              // Radio dot
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? activeColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSummary() {
    if (_selected == null) return const SizedBox.shrink();

    final isPaid = _selected == InvoicePaymentStatus.paid;
    final newOutstanding = isPaid
        ? widget.priorOutstanding
        : widget.priorOutstanding + widget.grandTotal;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaid ? Colors.green.shade300 : Colors.orange.shade300,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Status',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: isPaid
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isPaid
                          ? Colors.green.shade400
                          : Colors.orange.shade400,
                    ),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'ADDED TO A/C',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isPaid
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Outstanding',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: isPaid
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                Text(
                  '₹${_formatAmount(newOutstanding)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isPaid
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F1FB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _primaryRoyalBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Generated',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                Text(
                  widget.invoiceNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryRoyalBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // ── Customer strip ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CUSTOMER',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          widget.invoiceDate,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.customer.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 13, color: _primaryRoyalBlue),
                        const SizedBox(width: 4),
                        Text(
                          widget.customer.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Items purchased ─────────────────────────────────────────────
              Text(
                'ITEMS PURCHASED',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ...groupCartItems(widget.items).map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.productName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                            ),
                            ...group.sizeLines.map(
                              (sl) => Text(
                                'Size ${sl.size} × ${sl.quantity}'
                                '${group.commonPrice == null ? '  ₹${_formatAmount(sl.unitPrice)}/pr' : ''}',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: _textSecondary),
                              ),
                            ),
                            if (group.commonPrice != null)
                              Text(
                                '₹${_formatAmount(group.commonPrice!)}/pr',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: _textSecondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'x${group.totalQty}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '₹${_formatAmount(group.totalAmount)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20, color: Color(0xFFEEEEEE)),

              // ── Grand Total ─────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  Text(
                    '₹${_formatAmount(widget.grandTotal)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryRoyalBlue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),

              // ── Payment Status selector ─────────────────────────────────────
              Text(
                'PAYMENT STATUS',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  _buildPaymentOption(
                    value: InvoicePaymentStatus.addToAccount,
                    label: 'Add to A/C',
                    subtitle: 'Bill pending',
                    icon: Icons.account_balance_wallet_rounded,
                    activeColor: Colors.orange.shade800,
                    activeBg: Colors.orange.shade50,
                    activeBorder: Colors.orange.shade400,
                  ),
                  const SizedBox(width: 10),
                  _buildPaymentOption(
                    value: InvoicePaymentStatus.paid,
                    label: 'Paid',
                    subtitle: 'Full payment',
                    icon: Icons.check_circle_rounded,
                    activeColor: Colors.green.shade700,
                    activeBg: Colors.green.shade50,
                    activeBorder: Colors.green.shade400,
                  ),
                ],
              ),

              // Validation error
              if (_showValidationError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Please select a payment status.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              // Dynamic status summary
              _buildStatusSummary(),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            // Print button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BillPreviewScreen(
                              customer: widget.customer,
                              invoiceNumber: widget.invoiceNumber,
                              // Pass the ISO timestamp so time can be extracted.
                              invoiceDate: widget.invoiceCreatedAt.isNotEmpty
                                  ? widget.invoiceCreatedAt
                                  : widget.invoiceDate,
                              items: widget.items,
                              grandTotal: widget.grandTotal,
                              paymentStatus:
                                  _selected == InvoicePaymentStatus.paid
                                      ? 'Paid'
                                      : 'Added to A/C',
                              priorOutstanding: widget.priorOutstanding,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text('Print',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryRoyalBlue,
                  side: const BorderSide(color: _primaryRoyalBlue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Done button
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRoyalBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text('Done',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
