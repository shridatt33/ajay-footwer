import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import '../models/product.dart';

class BarcodeService {
  const BarcodeService();

  static const BarcodeService instance = BarcodeService();

  /// Generates a standardized Code 128 product barcode/ID.
  String generateBarcode(int sequence) {
    return 'SWA-${sequence.toString().padLeft(6, '0')}';
  }

  /// Builds a high-resolution PNG image of the Code 128 barcode.
  Future<Uint8List> generateBarcodeImageBytes(
    String barcodeData, {
    double width = 800,
    double height = 300,
    bool drawText = true,
  }) async {
    final cleanData = barcodeData.trim();
    if (cleanData.isEmpty) {
      throw ArgumentError('Barcode data cannot be empty.');
    }

    final bc = Barcode.code128();

    // Render using Flutter Canvas to guarantee razor-sharp 1D barcode bars
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // White background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    // Let the Barcode library draw the bars directly to canvas
    final painter = _BarcodePainter(
      barcode: bc,
      data: cleanData,
      color: const ui.Color(0xFF000000),
      drawText: drawText,
    );

    painter.paint(canvas, ui.Size(width, height));

    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to generate barcode image.');
    }

    return byteData.buffer.asUint8List();
  }

  /// Generates a product sticker/label card image.
  Future<Uint8List> generateProductLabelCardBytes({
    required Product product,
    String shopName = 'Swamidatta Agencies',
    double width = 900,
    double height = 650,
  }) async {
    final barcodeBytes = await generateBarcodeImageBytes(
      product.displayBarcode,
      width: 700,
      height: 240,
      drawText: true,
    );

    final codec = await ui.instantiateImageCodec(barcodeBytes);
    final frame = await codec.getNextFrame();
    final barcodeImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Card background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    // Border
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(20, 20, width - 40, height - 40),
        const ui.Radius.circular(24),
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const ui.Color(0xFFCBD5E1),
    );

    // Shop Name
    final shopParagraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF0F172A),
        fontSize: 34,
        fontWeight: ui.FontWeight.w700,
      ))
      ..addText(shopName.toUpperCase());

    final shopLayout = shopParagraph.build()
      ..layout(ui.ParagraphConstraints(width: width - 80));
    canvas.drawParagraph(shopLayout, const ui.Offset(40, 50));

    // Product Name
    final nameParagraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF334155),
        fontSize: 30,
        fontWeight: ui.FontWeight.w600,
      ))
      ..addText(product.productName);

    final nameLayout = nameParagraph.build()
      ..layout(ui.ParagraphConstraints(width: width - 80));
    canvas.drawParagraph(nameLayout, const ui.Offset(40, 105));

    // Draw Barcode Image
    canvas.drawImageRect(
      barcodeImage,
      ui.Rect.fromLTWH(0, 0, barcodeImage.width.toDouble(), barcodeImage.height.toDouble()),
      ui.Rect.fromLTWH((width - 700) / 2, 170, 700, 240),
      ui.Paint(),
    );

    // Selling Price Tag (NEVER show purchase price)
    final priceText = 'MRP: ₹${product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2)}';
    final priceParagraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF0F172A),
        fontSize: 40,
        fontWeight: ui.FontWeight.w800,
      ))
      ..addText(priceText);

    final priceLayout = priceParagraph.build()
      ..layout(ui.ParagraphConstraints(width: width - 80));
    canvas.drawParagraph(priceLayout, const ui.Offset(40, 435));

    // Product Code
    final codeParagraph = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFF64748B),
        fontSize: 24,
        fontWeight: ui.FontWeight.w500,
      ))
      ..addText('Item Code: ${product.productId}');

    final codeLayout = codeParagraph.build()
      ..layout(ui.ParagraphConstraints(width: width - 80));
    canvas.drawParagraph(codeLayout, const ui.Offset(40, 500));

    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      throw StateError('Unable to generate product label image.');
    }

    return pngBytes.buffer.asUint8List();
  }

  /// Saves the product barcode image to local files.
  Future<File> saveBarcodeToDocuments(Product product) async {
    final bytes = await generateBarcodeImageBytes(product.displayBarcode);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${product.displayBarcode}-barcode.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Saves the complete product label card to Android Gallery or Documents.
  Future<void> saveBarcodeLabelToGallery(Product product, {String shopName = 'Swamidatta Agencies'}) async {
    final bytes = await generateProductLabelCardBytes(product: product, shopName: shopName);

    if (Platform.isAndroid) {
      const channel = MethodChannel('com.example.ajayfw/qr_gallery');
      final androidSdk = await channel.invokeMethod<int>('getAndroidSdk') ?? 0;
      if (androidSdk < 29) {
        final permissionStatus = await Permission.storage.request();
        if (!permissionStatus.isGranted) {
          throw Exception('Storage permission is required to save the barcode sticker.');
        }
      }

      final saved = await channel.invokeMethod<bool>('saveQrToGallery', {
        'imageBytes': bytes,
        'productId': product.displayBarcode,
      });

      if (saved != true) {
        throw StateError('Failed to save barcode image to Gallery.');
      }
    } else {
      await saveBarcodeToDocuments(product);
    }
  }

  /// Prints a single barcode sticker (e.g., standard thermal sticker 50mm x 30mm or A5/A6).
  Future<void> printSingleBarcode(Product product, {String shopName = 'Swamidatta Agencies'}) async {
    final pdfBytes = await buildSingleBarcodeStickerPdf(product, shopName: shopName);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Barcode_${product.displayBarcode}',
    );
  }

  /// Builds a PDF for a single barcode sticker.
  Future<Uint8List> buildSingleBarcodeStickerPdf(
    Product product, {
    String shopName = 'Swamidatta Agencies',
    PdfPageFormat format = const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                shopName,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                maxLines: 1,
              ),
              pw.Text(
                product.productName,
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                maxLines: 1,
              ),
              pw.Expanded(
                child: pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: product.displayBarcode,
                    drawText: true,
                    textStyle: const pw.TextStyle(fontSize: 6),
                    width: 44 * PdfPageFormat.mm,
                    height: 14 * PdfPageFormat.mm,
                  ),
                ),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    product.productId,
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                  pw.Text(
                    'Rs. ${product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2)}',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Prints an A4 Sheet containing barcode stickers (grid layout for sticker label sheets).
  Future<void> printBarcodeSheet({
    required List<Product> products,
    int copiesPerProduct = 1,
    String shopName = 'Swamidatta Agencies',
  }) async {
    final pdfBytes = await buildBarcodeSheetPdf(
      products: products,
      copiesPerProduct: copiesPerProduct,
      shopName: shopName,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Barcode_Sheet_A4',
    );
  }

  /// Generates A4 sheet with 3 columns x 8 rows (24 labels) or 3 x 10 rows (30 labels).
  Future<Uint8List> buildBarcodeSheetPdf({
    required List<Product> products,
    int copiesPerProduct = 1,
    String shopName = 'Swamidatta Agencies',
  }) async {
    final doc = pw.Document();

    // Flatten product items by requested copy count
    final items = <Product>[];
    for (final p in products) {
      for (var i = 0; i < copiesPerProduct; i++) {
        items.add(p);
      }
    }

    const labelsPerPage = 24; // 3 columns x 8 rows
    final totalPages = (items.length / labelsPerPage).ceil();

    for (var pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final startIndex = pageIdx * labelsPerPage;
      final pageItems = items.skip(startIndex).take(labelsPerPage).toList();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 8 * PdfPageFormat.mm, vertical: 10 * PdfPageFormat.mm),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 2.1,
              crossAxisSpacing: 4 * PdfPageFormat.mm,
              mainAxisSpacing: 4 * PdfPageFormat.mm,
              children: pageItems.map((p) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        shopName,
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                        maxLines: 1,
                      ),
                      pw.Text(
                        p.productName,
                        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                        maxLines: 1,
                      ),
                      pw.SizedBox(
                        width: 50 * PdfPageFormat.mm,
                        height: 15 * PdfPageFormat.mm,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: p.displayBarcode,
                          drawText: true,
                          textStyle: const pw.TextStyle(fontSize: 5.5),
                        ),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            p.productId,
                            style: const pw.TextStyle(fontSize: 5.5),
                          ),
                          pw.Text(
                            'Rs. ${p.price.toStringAsFixed(p.price % 1 == 0 ? 0 : 2)}',
                            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}

/// Custom painter that draws Code 128 barcode bars and text cleanly onto Flutter canvas.
class _BarcodePainter {
  _BarcodePainter({
    required this.barcode,
    required this.data,
    required this.color,
    this.drawText = true,
  });

  final Barcode barcode;
  final String data;
  final ui.Color color;
  final bool drawText;

  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;

    final textHeight = drawText ? 28.0 : 0.0;
    final barcodeHeight = size.height - textHeight - 16;
    final barcodeWidth = size.width - 40;

    // Generate barcode elements
    final operations = barcode.make(
      data,
      width: barcodeWidth,
      height: barcodeHeight,
      drawText: false,
    );

    // Shift to start position
    canvas.save();
    canvas.translate(20, 8);

    for (final op in operations) {
      if (op is BarcodeBar) {
        if (op.black) {
          canvas.drawRect(
            ui.Rect.fromLTWH(op.left, op.top, op.width, op.height),
            paint,
          );
        }
      }
    }
    canvas.restore();

    if (drawText) {
      final paragraph = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: ui.TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        ),
      )
        ..pushStyle(ui.TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: ui.FontWeight.w600,
          letterSpacing: 2,
        ))
        ..addText(data);

      final layout = paragraph.build()
        ..layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(layout, ui.Offset(0, size.height - textHeight - 4));
    }
  }
}
