import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/billing_cart_item.dart';
import '../models/customer.dart';
import '../models/shop_profile.dart';
import 'shop_profile_repository.dart';

// ── Internal helper ──────────────────────────────────────────────────────────

/// One row in the printed invoice = one product, with all its sizes grouped.
class _ProductGroup {
  final String productId;
  final String productName;
  /// Size → quantity pairs, in original order.
  final List<MapEntry<String, int>> sizeQtyEntries;
  final double unitPrice;
  final double productTotal; // sum of all size line totals

  const _ProductGroup({
    required this.productId,
    required this.productName,
    required this.sizeQtyEntries,
    required this.unitPrice,
    required this.productTotal,
  });

  /// Compact size string: "6×2, 7×3, 8×5"
  String get sizeQtyLabel =>
      sizeQtyEntries.map((e) => '${e.key}×${e.value}').join(', ');

  int get totalQty =>
      sizeQtyEntries.fold(0, (sum, e) => sum + e.value);
}

/// Groups a flat list of [BillingCartItem] (one entry per size) into
/// one [_ProductGroup] per product, preserving the order they appear.
List<_ProductGroup> _groupCartItems(List<BillingCartItem> items) {
  final Map<String, _ProductGroup> grouped = {};
  final List<String> order = [];

  for (final item in items) {
    final pid = item.product.productId;
    if (!grouped.containsKey(pid)) {
      order.add(pid);
      grouped[pid] = _ProductGroup(
        productId: pid,
        productName: item.product.productName,
        sizeQtyEntries: [MapEntry(item.selectedSize, item.quantity)],
        unitPrice: item.sellingPrice,
        productTotal: item.lineTotal,
      );
    } else {
      final existing = grouped[pid]!;
      grouped[pid] = _ProductGroup(
        productId: pid,
        productName: existing.productName,
        sizeQtyEntries: [
          ...existing.sizeQtyEntries,
          MapEntry(item.selectedSize, item.quantity),
        ],
        unitPrice: existing.unitPrice,
        productTotal: existing.productTotal + item.lineTotal,
      );
    }
  }

  return order.map((pid) => grouped[pid]!).toList();
}

/// Generates and prints a traditional Marathi shop bill (receipt style).
class BillPdfService {
  const BillPdfService();

  // Narrow receipt paper: 80 mm wide
  static const double _paperWidth = 80 * PdfPageFormat.mm;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> printBill({
    required Customer customer,
    required String invoiceNumber,
    required String invoiceDate,
    required List<BillingCartItem> items,
    required double grandTotal,
    String paymentStatus = 'Paid',
    double priorOutstanding = 0.0,
  }) async {
    final pdfBytes = await buildBillPdfBytes(
      customer: customer,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      items: items,
      grandTotal: grandTotal,
      paymentStatus: paymentStatus,
      priorOutstanding: priorOutstanding,
    );
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  Future<Uint8List> buildBillPdfBytes({
    required Customer customer,
    required String invoiceNumber,
    required String invoiceDate,
    required List<BillingCartItem> items,
    required double grandTotal,
    String paymentStatus = 'Paid',
    double priorOutstanding = 0.0,
  }) async {
    final shop = ShopProfileRepository.instance.current;
    final doc = pw.Document();

    final ttf = await PdfGoogleFonts.notoSansDevanagariRegular();
    final ttfBold = await PdfGoogleFonts.notoSansDevanagariBold();

    final isPaid = paymentStatus.toLowerCase() == 'paid';
    final totalOutstanding =
        isPaid ? priorOutstanding : priorOutstanding + grandTotal;

    doc.addPage(
      pw.MultiPage(
        pageFormat: _receiptFormat(),
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        build: (context) => [
          _buildHeader(shop, ttf, ttfBold),
          pw.SizedBox(height: 6),
          _dottedDivider(),
          pw.SizedBox(height: 4),
          _buildCustomerSection(customer, invoiceNumber, invoiceDate, ttf, ttfBold),
          pw.SizedBox(height: 4),
          _dottedDivider(),
          pw.SizedBox(height: 4),
          _buildItemTable(items, ttf, ttfBold),
          pw.SizedBox(height: 4),
          _dottedDivider(),
          pw.SizedBox(height: 4),
          _buildFinancialSummary(
            grandTotal: grandTotal,
            priorOutstanding: priorOutstanding,
            totalOutstanding: totalOutstanding,
            isPaid: isPaid,
            ttf: ttf,
            ttfBold: ttfBold,
          ),
          pw.SizedBox(height: 4),
          _dottedDivider(),
          pw.SizedBox(height: 4),
          _buildStatusBadge(isPaid, ttf, ttfBold),
          pw.SizedBox(height: 6),
          _dottedDivider(),
          pw.SizedBox(height: 6),
          _buildFooter(ttf),
        ],
      ),
    );

    return doc.save();
  }

  // ── Page format ─────────────────────────────────────────────────────────────

  PdfPageFormat _receiptFormat() =>
      PdfPageFormat(_paperWidth, double.infinity, marginAll: 0);

  // ── Header ──────────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(ShopProfile shop, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('॥ ॐ ॥',
            style: pw.TextStyle(font: ttfBold, fontSize: 13),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 3),
        pw.Text(shop.shopName,
            style: pw.TextStyle(font: ttfBold, fontSize: 12),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text(shop.address,
            style: pw.TextStyle(font: ttf, fontSize: 9),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text('मो. ${shop.mobile}',
            style: pw.TextStyle(font: ttf, fontSize: 9),
            textAlign: pw.TextAlign.center),
        if (shop.gstNumber.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('GSTIN: ${shop.gstNumber}',
              style: pw.TextStyle(font: ttf, fontSize: 8),
              textAlign: pw.TextAlign.center),
        ],
      ],
    );
  }

  // ── Customer / Bill Info ────────────────────────────────────────────────────

  pw.Widget _buildCustomerSection(
    Customer customer,
    String invoiceNumber,
    String invoiceDate,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    final dateStr = _formatDate(invoiceDate);
    final timeStr = _formatTime(invoiceDate);
    final billNo = invoiceNumber.split('-').last;
    final dateTimeStr = timeStr.isNotEmpty ? '$dateStr  वेळ: $timeStr' : dateStr;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _infoRow('ग्राहक', customer.name, ttf, ttfBold),
        pw.SizedBox(height: 3),
        _infoRow('मोबाईल', customer.mobile, ttf, ttfBold),
        pw.SizedBox(height: 3),
        _infoRow('दिनांक', dateTimeStr, ttf, ttfBold),
        pw.SizedBox(height: 3),
        _infoRow('बिल नं.', billNo, ttf, ttfBold),
      ],
    );
  }

  pw.Widget _infoRow(String label, String value, pw.Font ttf, pw.Font ttfBold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text('$label :', style: pw.TextStyle(font: ttf, fontSize: 9)),
        ),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(font: ttfBold, fontSize: 9)),
        ),
      ],
    );
  }

  // ── Item table — ONE row per product, sizes grouped inside ──────────────────

  pw.Widget _buildItemTable(
      List<BillingCartItem> items, pw.Font ttf, pw.Font ttfBold) {
    final headerStyle = pw.TextStyle(font: ttfBold, fontSize: 8.5);
    final nameStyle   = pw.TextStyle(font: ttfBold, fontSize: 8.5);
    final sizeStyle   = pw.TextStyle(font: ttf, fontSize: 7.5);
    final cellStyle   = pw.TextStyle(font: ttf, fontSize: 8.5);
    final amtStyle    = pw.TextStyle(font: ttfBold, fontSize: 8.5);

    final groups = _groupCartItems(items);

    final List<pw.TableRow> rows = [
      // Header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _tableCell('क्र.', headerStyle, align: pw.TextAlign.center),
          _tableCell('माल / आकार × नग', headerStyle),
          _tableCell('दर', headerStyle, align: pw.TextAlign.right),
          _tableCell('रुपये', headerStyle, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (int i = 0; i < groups.length; i++) {
      final g = groups[i];

      final descCell = pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Product name (bold)
            pw.Text(g.productName, style: nameStyle),
            // All sizes on one compact line: "6×2, 7×3, 8×5"
            pw.Text(g.sizeQtyLabel, style: sizeStyle),
          ],
        ),
      );

      rows.add(pw.TableRow(children: [
        _tableCell('${i + 1}', cellStyle, align: pw.TextAlign.center),
        descCell,
        _tableCell(_formatAmount(g.unitPrice), cellStyle, align: pw.TextAlign.right),
        _tableCell(_formatAmount(g.productTotal), amtStyle, align: pw.TextAlign.right),
      ]));
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(20),   // क्र.
        1: const pw.FlexColumnWidth(3),      // माल / आकार × नग
        2: const pw.FixedColumnWidth(40),   // दर
        3: const pw.FixedColumnWidth(44),   // रुपये
      },
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
      children: rows,
    );
  }

  pw.Widget _tableCell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  // ── Financial summary (Marathi) ──────────────────────────────────────────────
  // Order: वर्तमान बिल → मागील बाकी → भरलेली/नवीन → एकूण बाकी

  pw.Widget _buildFinancialSummary({
    required double grandTotal,
    required double priorOutstanding,
    required double totalOutstanding,
    required bool isPaid,
    required pw.Font ttf,
    required pw.Font ttfBold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. Current bill
        _summaryRow('वर्तमान बिल :', '₹${_formatAmount(grandTotal)}',
            ttf, ttfBold, valueColor: PdfColors.black),
        pw.SizedBox(height: 3),
        // 2. Previous pending
        _summaryRow('मागील बाकी :', '₹${_formatAmount(priorOutstanding)}',
            ttf, ttfBold, valueColor: PdfColors.black),
        pw.SizedBox(height: 3),
        // 3. Paid / Added to A/C label
        _summaryRow(
          isPaid ? 'भरलेली रक्कम :' : 'नवीन बाकी (A/C) :',
          '₹${_formatAmount(grandTotal)}',
          ttf,
          ttfBold,
          valueColor: isPaid ? PdfColors.green800 : PdfColors.orange800,
        ),
        pw.SizedBox(height: 3),
        pw.Divider(thickness: 0.8, color: PdfColors.black),
        pw.SizedBox(height: 3),
        // 4. Total outstanding
        _summaryRow(
          'एकूण बाकी :',
          '₹${_formatAmount(totalOutstanding)}',
          ttf,
          ttfBold,
          bold: true,
          valueColor: totalOutstanding > 0 ? PdfColors.red700 : PdfColors.green700,
        ),
      ],
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    pw.Font ttf,
    pw.Font ttfBold, {
    bool bold = false,
    PdfColor valueColor = PdfColors.black,
  }) {
    final style = bold
        ? pw.TextStyle(font: ttfBold, fontSize: 10)
        : pw.TextStyle(font: ttf, fontSize: 10);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value,
            style: pw.TextStyle(font: ttfBold, fontSize: 10, color: valueColor)),
      ],
    );
  }

  // ── Payment status badge ────────────────────────────────────────────────────

  pw.Widget _buildStatusBadge(bool isPaid, pw.Font ttf, pw.Font ttfBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('स्थिती :', style: pw.TextStyle(font: ttf, fontSize: 9)),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: isPaid ? PdfColors.green700 : PdfColors.orange700),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            color: isPaid ? PdfColors.green50 : PdfColors.orange50,
          ),
          child: pw.Text(
            isPaid ? 'भरलेले (PAID)' : 'खात्यात (ADDED TO A/C)',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 8.5,
              color: isPaid ? PdfColors.green800 : PdfColors.orange800,
            ),
          ),
        ),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────

  pw.Widget _buildFooter(pw.Font ttf) {
    return pw.Center(
      child: pw.Text(
        'धन्यवाद! पुन्हा या.',
        style: pw.TextStyle(font: ttf, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ── Divider ──────────────────────────────────────────────────────────────────

  pw.Widget _dottedDivider() {
    return pw.SizedBox(
      height: 1,
      child: pw.Divider(thickness: 0.5, color: PdfColors.grey600),
    );
  }

  // ── Date/Time helpers ─────────────────────────────────────────────────────────

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

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour, m = dt.minute;
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '';
    }
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(amount % 1 == 0 ? 0 : 2)
        .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
