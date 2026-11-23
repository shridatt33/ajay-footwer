import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/bill.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({super.key, required this.bill});

  final Bill bill;

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  bool _isPrinting = false;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  String _formatAmount(double v) {
    return v
        .toStringAsFixed(v % 1 == 0 ? 0 : 2)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},');
  }

  /// "DD Mon YYYY" → "DD/MM/YYYY", also handles ISO strings.
  String _convertDate(String raw) {
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

  /// Returns "hh:mm AM/PM" from ISO string, or '' if not parseable.
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

  // ── PDF Generation ───────────────────────────────────────────────────────────

  Future<Uint8List> _buildPdfBytes() async {
    final bill = widget.bill;
    final bp = bill.businessProfile;

    final ttf = await PdfGoogleFonts.notoSansDevanagariRegular();
    final ttfBold = await PdfGoogleFonts.notoSansDevanagariBold();

    const paperWidth = 80 * PdfPageFormat.mm;
    final doc = pw.Document();

    final isPaid = bill.status.toLowerCase() == 'paid';
    final dateStr = _convertDate(bill.displayDate);
    final timeStr = _formatTime(bill.createdAt);
    final dateTimeStr =
        timeStr.isNotEmpty ? '$dateStr  वेळ: $timeStr' : dateStr;
    final billNo = bill.invoiceNo.split('-').last;

    final priorOutstanding = bill.priorOutstanding;
    final totalOutstanding =
        isPaid ? priorOutstanding : priorOutstanding + bill.grandTotal;

    doc.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat(paperWidth, double.infinity, marginAll: 0),
        margin:
            const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        build: (ctx) => [
          // ── Header ─────────────────────────────────────────────────────
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('॥ ॐ ॥',
                  style: pw.TextStyle(font: ttfBold, fontSize: 13),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 3),
              pw.Text(bp.shopName.isNotEmpty ? bp.shopName : 'Shop',
                  style: pw.TextStyle(font: ttfBold, fontSize: 12),
                  textAlign: pw.TextAlign.center),
              if (bp.address.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(bp.address,
                    style: pw.TextStyle(font: ttf, fontSize: 9),
                    textAlign: pw.TextAlign.center),
              ],
              if (bp.mobile.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('मो. ${bp.mobile}',
                    style: pw.TextStyle(font: ttf, fontSize: 9),
                    textAlign: pw.TextAlign.center),
              ],
              if (bp.gstNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('GSTIN: ${bp.gstNumber}',
                    style: pw.TextStyle(font: ttf, fontSize: 8),
                    textAlign: pw.TextAlign.center),
              ],
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 4),

          // ── Customer / bill info ────────────────────────────────────────
          _pdfInfoRow('ग्राहक', bill.customerName, ttf, ttfBold),
          pw.SizedBox(height: 3),
          if (bill.customerShopName.isNotEmpty) ...[
            _pdfInfoRow('दुकान', bill.customerShopName, ttf, ttfBold),
            pw.SizedBox(height: 3),
          ],
          _pdfInfoRow('मोबाईल', bill.customerMobile, ttf, ttfBold),
          pw.SizedBox(height: 3),
          _pdfInfoRow('दिनांक', dateTimeStr, ttf, ttfBold),
          pw.SizedBox(height: 3),
          _pdfInfoRow('बिल नं.', billNo, ttf, ttfBold),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 4),

          // ── Items table — ONE row per product, sizes grouped ─────────────
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(40),
              3: const pw.FixedColumnWidth(44),
            },
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
            children: () {
              final headerStyle = pw.TextStyle(font: ttfBold, fontSize: 8.5);
              final nameStyle   = pw.TextStyle(font: ttfBold, fontSize: 8.5);
              final sizeStyle   = pw.TextStyle(font: ttf, fontSize: 7.5);
              final cellStyle   = pw.TextStyle(font: ttf, fontSize: 8.5);
              final amtStyle    = pw.TextStyle(font: ttfBold, fontSize: 8.5);

              final List<pw.TableRow> rows = [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('क्र.', headerStyle, align: pw.TextAlign.center),
                    _pdfCell('माल / आकार × नग', headerStyle),
                    _pdfCell('दर', headerStyle, align: pw.TextAlign.right),
                    _pdfCell('रुपये', headerStyle, align: pw.TextAlign.right),
                  ],
                ),
              ];

              // Group by productId
              final Map<String, List<dynamic>> grouped = {};
              final List<String> order = [];
              for (final item in bill.products) {
                if (!grouped.containsKey(item.productId)) {
                  order.add(item.productId);
                  grouped[item.productId] = [item];
                } else {
                  grouped[item.productId]!.add(item);
                }
              }

              for (int i = 0; i < order.length; i++) {
                final pid = order[i];
                final sizeItems = grouped[pid]!;
                final first = sizeItems.first as dynamic;
                final double unitPrice = (first.unitPrice as num).toDouble();
                double productTotal = 0;
                final sizeParts = <String>[];
                for (final si in sizeItems) {
                  final d = si as dynamic;
                  productTotal += (d.lineTotal as num).toDouble();
                  sizeParts.add('${d.size}×${d.quantity}');
                }
                final sizeLabel = sizeParts.join(', ');

                final descCell = pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(first.productName as String, style: nameStyle),
                      pw.Text(sizeLabel, style: sizeStyle),
                    ],
                  ),
                );

                rows.add(pw.TableRow(children: [
                  _pdfCell('${i + 1}', cellStyle, align: pw.TextAlign.center),
                  descCell,
                  _pdfCell(_formatAmount(unitPrice), cellStyle, align: pw.TextAlign.right),
                  _pdfCell(_formatAmount(productTotal), amtStyle, align: pw.TextAlign.right),
                ]));
              }
              return rows;
            }(),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 4),

          // ── Bill total ──────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('एकूण बिल :',
                  style: pw.TextStyle(font: ttfBold, fontSize: 11)),
              pw.Text('₹${_formatAmount(bill.grandTotal)}',
                  style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 4),

          // ── Financial summary ────────────────────────────────────────────
          // Order: वर्तमान बिल → मागील बाकी → भरलेली/नवीन → एकूण बाकी
          _pdfSummaryRow(
            'वर्तमान बिल :',
            '₹${_formatAmount(bill.grandTotal)}',
            ttf, ttfBold,
          ),
          pw.SizedBox(height: 3),
          _pdfSummaryRow(
            'मागील बाकी :',
            '₹${_formatAmount(priorOutstanding)}',
            ttf, ttfBold,
          ),
          pw.SizedBox(height: 3),
          _pdfSummaryRow(
            isPaid ? 'भरलेली रक्कम :' : 'नवीन बाकी (A/C) :',
            '₹${_formatAmount(bill.grandTotal)}',
            ttf, ttfBold,
            valueColor: isPaid ? PdfColors.green800 : PdfColors.orange800,
          ),
          pw.SizedBox(height: 3),
          pw.Divider(thickness: 0.8, color: PdfColors.black),
          pw.SizedBox(height: 3),
          _pdfSummaryRow(
            'एकूण बाकी :',
            '₹${_formatAmount(totalOutstanding)}',
            ttf, ttfBold,
            bold: true,
            valueColor: totalOutstanding > 0
                ? PdfColors.red700
                : PdfColors.green700,
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 4),

          // ── Payment status badge ────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('स्थिती :',
                  style: pw.TextStyle(font: ttf, fontSize: 9)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: isPaid
                        ? PdfColors.green700
                        : PdfColors.orange700,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(3)),
                  color:
                      isPaid ? PdfColors.green50 : PdfColors.orange50,
                ),
                child: pw.Text(
                  isPaid
                      ? 'भरलेले (PAID)'
                      : 'खात्यात (ADDED TO A/C)',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 8.5,
                    color: isPaid
                        ? PdfColors.green800
                        : PdfColors.orange800,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text('धन्यवाद! पुन्हा या.',
                style: pw.TextStyle(font: ttf, fontSize: 9),
                textAlign: pw.TextAlign.center),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfInfoRow(
      String label, String value, pw.Font ttf, pw.Font ttfBold) {
    return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
              width: 90,
              child: pw.Text('$label :',
                  style: pw.TextStyle(font: ttf, fontSize: 9))),
          pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(font: ttfBold, fontSize: 9))),
        ]);
  }

  pw.Widget _pdfCell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  pw.Widget _pdfSummaryRow(
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
            style: pw.TextStyle(
                font: ttfBold, fontSize: 10, color: valueColor)),
      ],
    );
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF generation failed: $e',
              style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 13, color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final bp = bill.businessProfile;
    final isPaid = bill.status.toLowerCase() == 'paid';
    final isOnAccount = bill.status.toLowerCase() == 'added to a/c';
    final totalOutstanding = isPaid
        ? bill.priorOutstanding
        : bill.priorOutstanding + bill.grandTotal;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          bill.invoiceNo,
          style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textDark),
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
                            strokeWidth: 2.5)),
                  ),
                )
              : IconButton(
                  onPressed: _print,
                  icon: const Icon(Icons.print_rounded, color: _blue),
                  tooltip: 'Print / Download PDF',
                ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Business profile snapshot
              _card(children: [
                _sectionTitle('🏬 Shop Information'),
                const SizedBox(height: 10),
                _infoRow(Icons.store_rounded, 'Shop Name',
                    bp.shopName.isNotEmpty ? bp.shopName : '—'),
                _infoRow(Icons.phone_outlined, 'Mobile',
                    bp.mobile.isNotEmpty ? bp.mobile : '—'),
                _infoRow(Icons.location_on_outlined, 'Address',
                    bp.address.isNotEmpty ? bp.address : '—'),
                if (bp.gstNumber.isNotEmpty)
                  _infoRow(Icons.receipt_long_outlined, 'GSTIN',
                      bp.gstNumber),
              ]),
              const SizedBox(height: 12),

              // Bill info
              _card(children: [
                _sectionTitle('📋 Bill Details'),
                const SizedBox(height: 10),
                _infoRow(Icons.confirmation_number_outlined,
                    'Invoice No', bill.invoiceNo),
                _infoRow(Icons.calendar_today_outlined, 'Date & Time',
                    () {
                  final t = _formatTime(bill.createdAt);
                  final d = _convertDate(bill.displayDate);
                  return t.isNotEmpty ? '$d  $t' : d;
                }()),
                _infoRow(Icons.payment_rounded, 'Status', bill.status,
                    statusColor: isPaid
                        ? Colors.green.shade700
                        : isOnAccount
                            ? Colors.orange.shade700
                            : Colors.grey.shade700),
              ]),
              const SizedBox(height: 12),

              // Customer info
              _card(children: [
                _sectionTitle('👤 Customer'),
                const SizedBox(height: 10),
                _infoRow(Icons.person_outline_rounded, 'Name',
                    bill.customerName),
                if (bill.customerShopName.isNotEmpty)
                  _infoRow(Icons.storefront_rounded, 'Shop',
                      bill.customerShopName),
                if (bill.customerMobile.isNotEmpty)
                  _infoRow(Icons.phone_outlined, 'Mobile',
                      bill.customerMobile),
              ]),
              const SizedBox(height: 12),

              // Items
              _card(children: [
                _sectionTitle('🛍 Items Purchased'),
                const SizedBox(height: 10),
                // Table header
                Row(children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Text('Product / Sizes',
                        style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textSecondary)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('Amount',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textSecondary)),
                  ),
                ]),
                const Divider(height: 12),

                // ONE row per product — sizes grouped as "6×2, 7×3, 8×5"
                ...() {
                  final Map<String, List<BillItem>> grouped = {};
                  final List<String> order = [];
                  for (final item in bill.products) {
                    if (!grouped.containsKey(item.productId)) {
                      order.add(item.productId);
                      grouped[item.productId] = [item];
                    } else {
                      grouped[item.productId]!.add(item);
                    }
                  }

                  final List<Widget> rows = [];
                  for (int idx = 0; idx < order.length; idx++) {
                    final pid = order[idx];
                    final sizeItems = grouped[pid]!;
                    final first = sizeItems.first;
                    double productTotal = sizeItems.fold(0, (s, e) => s + e.lineTotal);
                    final sizeLabel = sizeItems
                        .map((e) => '${e.size}×${e.quantity}')
                        .join(', ');

                    rows.add(Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Index badge
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${idx + 1}',
                                style: TextStyle(fontFamily: 'Poppins', 
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _blue)),
                          ),
                          const SizedBox(width: 6),
                          // Product name + size label
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(first.productName,
                                    style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _textDark)),
                                Text(
                                  '$sizeLabel  •  ₹${_formatAmount(first.unitPrice)}/pr',
                                  style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 11, color: _textSecondary),
                                ),
                              ],
                            ),
                          ),
                          // Line total
                          SizedBox(
                            width: 70,
                            child: Text(
                              '₹${_formatAmount(productTotal)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _textDark),
                            ),
                          ),
                        ],
                      ),
                    ));
                  }
                  return rows;
                }(),

                const Divider(),
                if (bill.discount > 0) ...[
                  _totalRow(
                      'Subtotal', '₹${_formatAmount(bill.subtotal)}'),
                  _totalRow('Discount',
                      '- ₹${_formatAmount(bill.discount)}'),
                ],
                if (bill.tax > 0)
                  _totalRow('Tax', '+ ₹${_formatAmount(bill.tax)}'),
                _totalRow(
                  'Grand Total',
                  '₹${_formatAmount(bill.grandTotal)}',
                  bold: true,
                  fontSize: 15,
                ),
              ]),
              const SizedBox(height: 12),

              // ── Financial summary ─────────────────────────────────────────
              _card(children: [
                _sectionTitle('💰 Financial Summary'),
                const SizedBox(height: 10),
                _summaryInfoRow(
                  label: 'वर्तमान बिल (Current Bill)',
                  value: '₹${_formatAmount(bill.grandTotal)}',
                  valueColor: _textDark,
                ),
                const SizedBox(height: 8),
                _summaryInfoRow(
                  label: 'मागील बाकी (Prior Outstanding)',
                  value: '₹${_formatAmount(bill.priorOutstanding)}',
                  valueColor: _textDark,
                ),
                const SizedBox(height: 8),
                _summaryInfoRow(
                  label: isPaid ? 'भरलेली रक्कम (Paid)' : 'नवीन बाकी (Added to A/C)',
                  value: '₹${_formatAmount(bill.grandTotal)}',
                  valueColor: isPaid
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
                const Divider(height: 16, thickness: 0.8),
                _summaryInfoRow(
                  label: 'एकूण बाकी (Total Outstanding)',
                  value: '₹${_formatAmount(totalOutstanding)}',
                  valueColor: totalOutstanding > 0
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                  bold: true,
                  fontSize: 15,
                ),
              ]),
              const SizedBox(height: 20),

              // Print / Download button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isPrinting ? null : _print,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.print_rounded, size: 22),
                  label: Text(
                    _isPrinting
                        ? 'Generating PDF...'
                        : 'Print / Download PDF',
                    style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textDark));
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: _blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary)),
                Text(value,
                    style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusColor ?? _textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: fontSize,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500,
                  color: bold ? _textDark : _textSecondary)),
          Text(value,
              style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: fontSize,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? _blue : _textDark)),
        ],
      ),
    );
  }

  Widget _summaryInfoRow({
    required String label,
    required String value,
    required Color valueColor,
    bool bold = false,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: fontSize - 1,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? _textDark : _textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
