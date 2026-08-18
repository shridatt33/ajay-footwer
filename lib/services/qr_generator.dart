import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGeneratorService {
  const QrGeneratorService();

  String generateProductId(int sequence) {
    return 'SWA-${sequence.toString().padLeft(6, '0')}';
  }

  String buildQrData(String productId) {
    return productId;
  }

  Future<Uint8List> generateQrImageBytes(String qrData, {double size = 1024}) async {
    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: true,
      dataModuleStyle: const QrDataModuleStyle(
        color: Color(0xFF000000),
      ),
      eyeStyle: const QrEyeStyle(
        color: Color(0xFF000000),
        eyeShape: QrEyeShape.square,
      ),
    );

    final byteData = await painter.toImageData(size);
    if (byteData == null) {
      throw StateError('Unable to generate QR image.');
    }

    return byteData.buffer.asUint8List();
  }

  Future<File> saveQrImageToDocuments({
    required String qrData,
    required String productId,
  }) async {
    final bytes = await generateQrImageBytes(qrData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$productId-qr.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> printQrCode({
    required String qrData,
    required String productId,
  }) async {
    final pdfBytes = await buildQrPdfBytes(qrData: qrData, productId: productId);
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  Future<Uint8List> buildQrPdfBytes({
    required String qrData,
    required String productId,
  }) async {
    final qrBytes = await generateQrImageBytes(qrData, size: 720);
    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'Swamidatta Agencies',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(qrBytes),
                    width: 220,
                    height: 220,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  productId,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Product QR Code'),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }
}