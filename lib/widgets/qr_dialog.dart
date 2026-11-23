import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

class QrDialog extends StatefulWidget {
  const QrDialog({
    super.key,
    required this.productId,
    this.productName,
    required this.qrData,
    required this.onDownload,
    required this.onPrint,
  });

  final String productId;
  final String? productName;
  final String qrData;
  final Future<void> Function() onDownload;
  final Future<void> Function() onPrint;

  @override
  State<QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<QrDialog> {
  bool _isBusy = false;

  Future<void> _handleDownload() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await widget.onDownload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcode downloaded successfully.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handlePrint() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await widget.onPrint();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Barcode Generated',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code 128 format • Standard USB/BT scanner readable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: widget.qrData,
                    width: 250,
                    height: 90,
                    drawText: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.productId,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
              ),
              if (widget.productName != null &&
                  widget.productName!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.productName!.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _handleDownload,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Barcode'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : _handlePrint,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Print Barcode'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
