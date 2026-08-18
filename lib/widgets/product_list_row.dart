import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductListRow extends StatelessWidget {
  const ProductListRow({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onQrPressed,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onQrPressed;

  String _formatPrice() {
    return '₹${product.price.toStringAsFixed(product.price % 1 == 0 ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasCategoryName =
        product.categoryName != null && product.categoryName!.isNotEmpty;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.hiking_rounded,
                  color: Color(0xFF1565C0),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.productId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasCategoryName) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F1FB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF1565C0).withAlpha(60),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Category: ${product.categoryName}',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatPrice(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onQrPressed,
                tooltip: 'QR Code',
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onEditPressed,
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_rounded, size: 20),
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onDeletePressed,
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
