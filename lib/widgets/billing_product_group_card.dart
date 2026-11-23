import 'package:flutter/material.dart';
import '../models/billing_cart_item.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

/// A mobile-first, compact product card for the POS billing screen that groups
/// all selected sizes for a given product together in one clean, unified card.
class BillingProductGroupCard extends StatelessWidget {
  const BillingProductGroupCard({
    super.key,
    required this.product,
    required this.items,
    required this.onQuantityChanged,
    required this.onRemoveItem,
    required this.onRemoveProduct,
    required this.onAddMoreSizes,
    this.onPriceChanged,
  });

  final Product product;
  final List<BillingCartItem> items;
  final void Function(BillingCartItem item, int newQty) onQuantityChanged;
  final void Function(BillingCartItem item) onRemoveItem;
  final void Function(Product product) onRemoveProduct;
  final void Function(Product product) onAddMoreSizes;
  final void Function(Product product, double newPrice)? onPriceChanged;

  int get _totalProductPairs {
    return items.fold<int>(0, (sum, i) => sum + i.quantity);
  }

  double get _totalProductAmount {
    return items.fold<double>(0, (sum, i) => sum + i.lineTotal);
  }

  void _showPriceEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: items.first.sellingPrice.toStringAsFixed(items.first.sellingPrice % 1 == 0 ? 0 : 2),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Selling Price',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update price per pair for ${product.productName}:',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Price per Pair',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newPrice = double.tryParse(controller.text.trim());
                if (newPrice != null && newPrice > 0) {
                  onPriceChanged?.call(product, newPrice);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitPrice = items.isNotEmpty ? items.first.sellingPrice : product.price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Product Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            product.productId,
                            style: TextStyle(fontFamily: 'monospace', 
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                          InkWell(
                            onTap: () => _showPriceEditDialog(context),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${unitPrice.toStringAsFixed(unitPrice % 1 == 0 ? 0 : 2)}/pr',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Add more sizes & Remove product buttons
                IconButton(
                  onPressed: () => onAddMoreSizes(product),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  color: AppColors.primary,
                  tooltip: 'Add more sizes',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => onRemoveProduct(product),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.error,
                  tooltip: 'Remove product',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // ── Size Rows (Compact, Clean, Mobile-First) ───────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 12, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final item = items[index];
              final maxStock = item.availableStock;
              final canIncrement = item.quantity < maxStock;
              final canDecrement = item.quantity > 1;

              return Row(
                children: [
                  // Size badge
                  Container(
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        item.selectedSize,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Stock indicator
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Size ${item.selectedSize}',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Stock: $maxStock',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quantity Stepper
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: canDecrement
                              ? () => onQuantityChanged(item, item.quantity - 1)
                              : () => onRemoveItem(item),
                          icon: Icon(
                            item.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                            size: 16,
                            color: item.quantity == 1 ? AppColors.error : AppColors.textPrimary,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            item.quantity.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: canIncrement
                              ? () => onQuantityChanged(item, item.quantity + 1)
                              : null,
                          icon: Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: canIncrement ? AppColors.textPrimary : Colors.grey.shade400,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Line Total
                  SizedBox(
                    width: 62,
                    child: Text(
                      '₹${item.lineTotal.toStringAsFixed(item.lineTotal % 1 == 0 ? 0 : 2)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Product Summary Footer (If multi-size) ─────────────────────
          if (items.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_totalProductPairs pairs total across ${items.length} sizes',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Subtotal: ₹${_totalProductAmount.toStringAsFixed(_totalProductAmount % 1 == 0 ? 0 : 2)}',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
