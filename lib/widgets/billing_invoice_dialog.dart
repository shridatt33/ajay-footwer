import 'package:flutter/material.dart';

import '../models/bill.dart';

class BillingInvoiceDialog extends StatelessWidget {
  const BillingInvoiceDialog({
    super.key,
    required this.bill,
  });

  final Bill bill;

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(amount % 1 == 0 ? 0 : 2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Invoice Generated'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (bill.customerShopName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(bill.customerShopName),
                  ],
                  if (bill.customerMobile.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(bill.customerMobile),
                  ],
                  const SizedBox(height: 2),
                  Text('Invoice No: ${bill.invoiceNo}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...bill.products.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName}  •  Size ${item.size}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('x${item.quantity}'),
                    const SizedBox(width: 12),
                    Text('₹${_formatAmount(item.lineTotal)}'),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '₹${_formatAmount(bill.grandTotal)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}