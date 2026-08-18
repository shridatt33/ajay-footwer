import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ajayfw/widgets/qr_dialog.dart';

void main() {
  testWidgets('QrDialog displays both Product ID and Product Name',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrDialog(
            productId: 'SWA-000001',
            productName: 'Nike Air Max 90',
            qrData: 'SWA-000001',
            onDownload: () async {},
            onPrint: () async {},
          ),
        ),
      ),
    );

    expect(find.text('QR Code Generated'), findsOneWidget);
    expect(find.text('SWA-000001'), findsOneWidget);
    expect(find.text('Nike Air Max 90'), findsOneWidget);
    expect(find.text('Download QR'), findsOneWidget);
    expect(find.text('Print QR'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
