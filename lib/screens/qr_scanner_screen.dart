import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';

/// Legacy alias for [BarcodeScannerScreen]
class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BarcodeScannerScreen();
  }
}
