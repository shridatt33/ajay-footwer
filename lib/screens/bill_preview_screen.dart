import 'package:flutter/material.dart';
import '../models/billing_cart_item.dart';
import '../models/customer.dart';
import '../services/bill_pdf_service.dart';
import '../services/shop_profile_repository.dart';

/// Shows a traditional Marathi shop bill preview and allows printing/downloading.
class BillPreviewScreen extends StatefulWidget {
  final Customer customer;
  final String invoiceNumber;
  /// Human-readable date OR an ISO datetime string.
  /// If ISO (contains 'T'), both date and time are extracted.
  final String invoiceDate;
  final List<BillingCartItem> items;
  final double grandTotal;
  final String paymentStatus;
  /// Customer's outstanding balance BEFORE this bill (used for summary section).
  final double priorOutstanding;

  const BillPreviewScreen({
    super.key,
    required this.customer,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.items,
    required this.grandTotal,
    this.paymentStatus = 'Paid',
    this.priorOutstanding = 0.0,
  });

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  bool _isPrinting = false;

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      await const BillPdfService().printBill(
        customer: widget.customer,
        invoiceNumber: widget.invoiceNumber,
        invoiceDate: widget.invoiceDate,
        items: widget.items,
        grandTotal: widget.grandTotal,
        paymentStatus: widget.paymentStatus,
        priorOutstanding: widget.priorOutstanding,
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── Formatting helpers ──────────────────────────────────────────────────────

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(amount % 1 == 0 ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  /// Returns DD/MM/YYYY from either "DD Mon YYYY" or ISO string.
  String _formatDate(String raw) {
    if (raw.contains('T') || RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        return '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
      } catch (_) {}
    }
    const months = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
      'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
      'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
    };
    final parts = raw.split(' ');
    if (parts.length == 3) {
      return '${parts[0]}/${months[parts[1]] ?? parts[1]}/${parts[2]}';
    }
    return raw;
  }

  /// Returns "hh:mm AM/PM" from ISO string, or empty string if not parseable.
  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour = dt.hour;
      final minute = dt.minute;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour % 12 == 0 ? 12 : hour % 12;
      return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '';
    }
  }

  // ── Bill UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shop = ShopProfileRepository.instance.current;
    final billNo = widget.invoiceNumber.split('-').last;
    final dateStr = _formatDate(widget.invoiceDate);
    final timeStr = _formatTime(widget.invoiceDate);
    final isPaid = widget.paymentStatus.toLowerCase() == 'paid';

    // Financial summary values
    final currentBill = widget.grandTotal;
    final prior = widget.priorOutstanding;
    final totalOutstanding = isPaid ? prior : prior + currentBill;

    return Scaffold(
      backgroundColor: const Color(0xFFD6CFC4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A3728),
        foregroundColor: Colors.white,
        title: Text(
          'बिल पूर्वावलोकन',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          _isPrinting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _print,
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'Print / Download',
                ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Shop header ──────────────────────────────────────────
                    _centeredText('॥ ॐ ॥', bold: true, size: 14),
                    const SizedBox(height: 4),
                    _centeredText(shop.shopName, bold: true, size: 13),
                    const SizedBox(height: 2),
                    _centeredText(shop.address, size: 10),
                    const SizedBox(height: 2),
                    _centeredText('मो. ${shop.mobile}', size: 10),
                    if (shop.gstNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _centeredText('GSTIN: ${shop.gstNumber}', size: 9),
                    ],
                    const SizedBox(height: 6),
                    _dottedDivider(),
                    const SizedBox(height: 6),

                    // ── Customer info ────────────────────────────────────────
                    _infoRow('ग्राहक', widget.customer.name),
                    const SizedBox(height: 3),
                    _infoRow('मोबाईल', widget.customer.mobile),
                    const SizedBox(height: 3),
                    // Date + Time on same row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: const Text('दिनांक :',
                              style: TextStyle(fontSize: 10)),
                        ),
                        Expanded(
                          child: Text(
                            timeStr.isNotEmpty
                                ? '$dateStr  वेळ: $timeStr'
                                : dateStr,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _infoRow('बिल नं.', billNo),
                    const SizedBox(height: 6),
                    _dottedDivider(),
                    const SizedBox(height: 6),

                    // ── Item table ────────────────────────────────────────────
                    _buildItemTable(),
                    const SizedBox(height: 6),
                    _dottedDivider(),
                    const SizedBox(height: 6),

                    // ── Current bill total ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('एकूण बिल :',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(
                          '₹${_formatAmount(currentBill)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _dottedDivider(),
                    const SizedBox(height: 6),

                    // ── Financial summary ─────────────────────────────────────
                    // Order: वर्तमान बिल → मागील बाकी → भरलेली/नवीन → एकूण बाकी
                    _summaryRow('वर्तमान बिल :', '₹${_formatAmount(currentBill)}'),
                    const SizedBox(height: 4),
                    _summaryRow('मागील बाकी :', '₹${_formatAmount(prior)}'),
                    const SizedBox(height: 4),
                    if (isPaid) ...[
                      _summaryRow(
                        'भरलेली रक्कम :',
                        '₹${_formatAmount(currentBill)}',
                        valueColor: Colors.green.shade700,
                      ),
                    ] else ...[
                      _summaryRow(
                        'नवीन बाकी (A/C) :',
                        '₹${_formatAmount(currentBill)}',
                        valueColor: Colors.orange.shade800,
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Divider(height: 1, thickness: 0.8, color: Colors.black),
                    const SizedBox(height: 4),
                    _summaryRow(
                      'एकूण बाकी :',
                      '₹${_formatAmount(totalOutstanding)}',
                      bold: true,
                      valueColor: totalOutstanding > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                    const SizedBox(height: 6),
                    _dottedDivider(),
                    const SizedBox(height: 6),

                    // ── Payment status badge ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('स्थिती :',
                            style: TextStyle(fontSize: 10)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            border: Border.all(
                              color: isPaid
                                  ? Colors.green.shade400
                                  : Colors.orange.shade400,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPaid ? 'भरलेले (PAID)' : 'खात्यात (ADDED TO A/C)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _dottedDivider(),
                    const SizedBox(height: 8),

                    // ── Footer ────────────────────────────────────────────────
                    _centeredText('धन्यवाद! पुन्हा या.', size: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _isPrinting ? null : _print,
              icon: const Icon(Icons.print_rounded, size: 20),
              label: Text(
                'Print / Download',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A3728),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Item table widget ────────────────────────────────────────────────────────

  Widget _buildItemTable() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5);
    const nameStyle   = TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5);
    const sizeStyle   = TextStyle(fontSize: 8.0, color: Color(0xFF627D98));
    const cellStyle   = TextStyle(fontSize: 9.5);
    const amtStyle    = TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5);

    // Group items by productId — one table row per product.
    final Map<String, List<BillingCartItem>> grouped = {};
    final List<String> order = [];

    for (final item in widget.items) {
      final pid = item.product.productId;
      if (!grouped.containsKey(pid)) {
        order.add(pid);
        grouped[pid] = [item];
      } else {
        grouped[pid]!.add(item);
      }
    }

    final List<TableRow> rows = [
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: [
          _tCell('क्र.', headerStyle, align: TextAlign.center),
          _tCell('माल / आकार × नग', headerStyle),
          _tCell('दर', headerStyle, align: TextAlign.right),
          _tCell('रुपये', headerStyle, align: TextAlign.right),
        ],
      ),
    ];

    for (int i = 0; i < order.length; i++) {
      final pid = order[i];
      final sizeItems = grouped[pid]!;
      final firstName = sizeItems.first.product.productName;
      final unitPrice = sizeItems.first.sellingPrice;
      final productTotal = sizeItems.fold<double>(0, (s, e) => s + e.lineTotal);

      // "6×2, 7×3, 8×5"
      final sizeLabel =
          sizeItems.map((e) => '${e.selectedSize}×${e.quantity}').join(', ');

      final descWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(firstName, style: nameStyle),
            Text(sizeLabel, style: sizeStyle),
          ],
        ),
      );

      rows.add(TableRow(
        children: [
          _tCell('${i + 1}', cellStyle, align: TextAlign.center),
          descWidget,
          _tCell(_formatAmount(unitPrice), cellStyle, align: TextAlign.right),
          _tCell(_formatAmount(productTotal), amtStyle, align: TextAlign.right),
        ],
      ));
    }

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(22),
        1: FlexColumnWidth(3),
        2: FixedColumnWidth(44),
        3: FixedColumnWidth(52),
      },
      border: TableBorder.all(width: 0.5),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows,
    );
  }

  Widget _tCell(String text, TextStyle style,
      {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Text(text, style: style, textAlign: align),
    );
  }

  // ── Small helpers ────────────────────────────────────────────────────────────

  Widget _centeredText(String text,
      {bool bold = false, double size = 11}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: size,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text('$label :', style: const TextStyle(fontSize: 10)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    final weight = bold ? FontWeight.bold : FontWeight.normal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, fontWeight: weight)),
        Text(value,
            style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor)),
      ],
    );
  }

  Widget _dottedDivider() {
    return const Divider(height: 1, thickness: 0.5, color: Colors.grey);
  }
}
