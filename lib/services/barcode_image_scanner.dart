import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeImageScannerService {
  const BarcodeImageScannerService();

  Future<String?> scanBarcodeFromImage({
    required MobileScannerController controller,
    required String imagePath,
  }) async {
    final capture = await controller.analyzeImage(imagePath);
    if (capture == null) {
      return null;
    }

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      return value;
    }

    return null;
  }
}
