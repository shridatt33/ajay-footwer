import 'dart:io';
import 'dart:typed_data';

import '../models/product.dart';
import 'barcode_service.dart';

/// Legacy compatibility wrapper delegating to [BarcodeService].
class QrGeneratorService {
  const QrGeneratorService();

  static const BarcodeService _barcodeService = BarcodeService.instance;

  String generateProductId(int sequence) {
    return _barcodeService.generateBarcode(sequence);
  }

  String buildQrData(String productId) {
    return productId;
  }

  Future<Uint8List> generateQrImageBytes(String qrData, {double size = 1024}) async {
    return _barcodeService.generateBarcodeImageBytes(
      qrData,
      width: size,
      height: size * 0.4,
    );
  }

  Future<Uint8List> generateProductQrCardBytes({
    required String qrData,
    required String productName,
    required String productCode,
    double width = 900,
    double height = 650,
  }) async {
    final product = Product(
      productId: productCode,
      productName: productName,
      sizeStock: {},
      price: 0,
      quantity: 0,
      barcode: qrData,
      qrData: qrData,
      createdAt: DateTime.now(),
    );
    return _barcodeService.generateProductLabelCardBytes(
      product: product,
      width: width,
      height: height,
    );
  }

  Future<void> saveProductQrCardToGallery({
    required String productName,
    required String productId,
    required String qrData,
  }) async {
    final product = Product(
      productId: productId,
      productName: productName,
      sizeStock: {},
      price: 0,
      quantity: 0,
      barcode: qrData,
      qrData: qrData,
      createdAt: DateTime.now(),
    );
    await _barcodeService.saveBarcodeLabelToGallery(product);
  }

  Future<void> saveQrCodeToGallery({
    required String qrData,
    required String productId,
  }) async {
    final product = Product(
      productId: productId,
      productName: productId,
      sizeStock: {},
      price: 0,
      quantity: 0,
      barcode: qrData,
      qrData: qrData,
      createdAt: DateTime.now(),
    );
    await _barcodeService.saveBarcodeLabelToGallery(product);
  }

  Future<File> saveQrImageToDocuments({
    required String qrData,
    required String productId,
  }) async {
    final product = Product(
      productId: productId,
      productName: productId,
      sizeStock: {},
      price: 0,
      quantity: 0,
      barcode: qrData,
      qrData: qrData,
      createdAt: DateTime.now(),
    );
    return _barcodeService.saveBarcodeToDocuments(product);
  }

  Future<void> saveProductPdfToDownloads(Product product) async {
    await _barcodeService.saveBarcodeLabelToGallery(product);
  }

  Future<void> printQrCode({
    required String qrData,
    required String productId,
  }) async {
    final product = Product(
      productId: productId,
      productName: productId,
      sizeStock: {},
      price: 0,
      quantity: 0,
      barcode: qrData,
      qrData: qrData,
      createdAt: DateTime.now(),
    );
    await _barcodeService.printSingleBarcode(product);
  }

  Future<Uint8List> buildProductPdfBytes(Product product) async {
    return _barcodeService.buildSingleBarcodeStickerPdf(product);
  }

  Future<Uint8List> buildQrPdfBytes({
    required String qrData,
    required String productId,
  }) async {
    final product = Product(
      productId: productId,
      productName: productId,
      sizeStock: {},
      price: 0,
      quantity: 0,
      barcode: qrData,
      qrData: qrData,
      createdAt: DateTime.now(),
    );
    return _barcodeService.buildSingleBarcodeStickerPdf(product);
  }
}
