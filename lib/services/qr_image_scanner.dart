import 'package:mobile_scanner/mobile_scanner.dart';
import 'barcode_image_scanner.dart';

class QrImageScannerService {
  const QrImageScannerService();

  static const BarcodeImageScannerService _delegate = BarcodeImageScannerService();

  Future<String?> scanProductIdFromImage({
    required MobileScannerController controller,
    required String imagePath,
  }) async {
    return _delegate.scanBarcodeFromImage(
      controller: controller,
      imagePath: imagePath,
    );
  }
}
