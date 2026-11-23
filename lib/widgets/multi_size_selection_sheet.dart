import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet that enables multi-size selection and quantity configuration
/// for a scanned footwear product in the POS/Billing screen.
class MultiSizeSelectionSheet extends StatefulWidget {
  const MultiSizeSelectionSheet({
    super.key,
    required this.product,
    required this.existingCartQuantities,
  });

  final Product product;

  /// Map of size -> quantity already in the cart for this product
  final Map<String, int> existingCartQuantities;

  static Future<Map<String, int>?> show(
    BuildContext context, {
    required Product product,
    required Map<String, int> existingCartQuantities,
  }) {
    return showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiSizeSelectionSheet(
        product: product,
        existingCartQuantities: existingCartQuantities,
      ),
    );
  }

  @override
  State<MultiSizeSelectionSheet> createState() => _MultiSizeSelectionSheetState();
}

class _MultiSizeSelectionSheetState extends State<MultiSizeSelectionSheet> {
  late final Map<String, int> _selectedQuantities;
  late final List<String> _sortedSizes;

  @override
  void initState() {
    super.initState();
    _sortedSizes = widget.product.sizeStock.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    // Default quantity is 1 for each available size that has stock > 0
    _selectedQuantities = <String, int>{};
    for (final size in _sortedSizes) {
      final totalStock = widget.product.sizeStock[size] ?? 0;
      final inCart = widget.existingCartQuantities[size] ?? 0;
      final remainingStock = totalStock - inCart;

      if (remainingStock > 0) {
        _selectedQuantities[size] = 1;
      } else {
        _selectedQuantities[size] = 0;
      }
    }
  }

  int get _totalSelectedPairs {
    return _selectedQuantities.values.fold<int>(0, (sum, q) => sum + q);
  }

  double get _totalPrice {
    return _totalSelectedPairs * widget.product.price;
  }

  int _maxAvailableToAdd(String size) {
    final totalStock = widget.product.sizeStock[size] ?? 0;
    final inCart = widget.existingCartQuantities[size] ?? 0;
    final remaining = totalStock - inCart;
    return remaining > 0 ? remaining : 0;
  }

  void _increment(String size) {
    final current = _selectedQuantities[size] ?? 0;
    final maxToAdd = _maxAvailableToAdd(size);
    if (current < maxToAdd) {
      setState(() {
        _selectedQuantities[size] = current + 1;
      });
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum available stock ($maxToAdd) reached for Size $size.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _decrement(String size) {
    final current = _selectedQuantities[size] ?? 0;
    if (current > 0) {
      setState(() {
        _selectedQuantities[size] = current - 1;
      });
    }
  }

  void _selectAllAvailable() {
    setState(() {
      for (final size in _sortedSizes) {
        final maxToAdd = _maxAvailableToAdd(size);
        _selectedQuantities[size] = maxToAdd > 0 ? 1 : 0;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final size in _sortedSizes) {
        _selectedQuantities[size] = 0;
      }
    });
  }

  void _confirmAddToBill() {
    final toAdd = <String, int>{};
    for (final entry in _selectedQuantities.entries) {
      if (entry.value > 0) {
        toAdd[entry.key] = entry.value;
      }
    }

    if (toAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one size with quantity greater than 0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(toAdd);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Product Header Card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.product.displayBarcode,
                                style: TextStyle(fontFamily: 'monospace', 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${widget.product.price.toStringAsFixed(widget.product.price % 1 == 0 ? 0 : 2)} / pair',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Quick Actions Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All Sizes (${_sortedSizes.length})',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectAllAvailable,
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: Text(
                      'All (1 each)',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: Text(
                      'Clear',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),

            // Multi-Size List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                itemCount: _sortedSizes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final size = _sortedSizes[index];
                  final totalStock = widget.product.sizeStock[size] ?? 0;
                  final inCart = widget.existingCartQuantities[size] ?? 0;
                  final maxToAdd = _maxAvailableToAdd(size);
                  final selectedQty = _selectedQuantities[size] ?? 0;
                  final isOutOfStock = totalStock <= 0;
                  final isMaxedOut = !isOutOfStock && maxToAdd <= 0;
                  final isSelected = selectedQty > 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight.withValues(alpha: 0.5)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Size tag
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              size,
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Stock and details info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Size $size',
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isOutOfStock)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.errorLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Out of stock',
                                        style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    )
                                  else if (isMaxedOut)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'All in bill ($inCart)',
                                        style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$totalStock in stock',
                                        style: TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inCart > 0
                                    ? 'In bill: $inCart pair${inCart > 1 ? 's' : ''} • Max can add: $maxToAdd'
                                    : 'Available to bill: $maxToAdd pairs',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quantity Stepper
                        if (isOutOfStock || isMaxedOut)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Decrement button
                              Material(
                                color: selectedQty > 0 ? Colors.white : Colors.grey.shade200,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: selectedQty > 0 ? () => _decrement(size) : null,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selectedQty > 0 ? AppColors.border : Colors.transparent,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 18,
                                      color: selectedQty > 0 ? AppColors.textPrimary : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),

                              // Quantity value
                              SizedBox(
                                width: 38,
                                child: Text(
                                  selectedQty.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: 'Poppins', 
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: selectedQty > 0 ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ),

                              // Increment button
                              Material(
                                color: selectedQty < maxToAdd ? AppColors.primary : Colors.grey.shade200,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: selectedQty < maxToAdd ? () => _increment(size) : null,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: const BoxDecoration(shape: BoxShape.circle),
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: selectedQty < maxToAdd ? Colors.white : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Add to Bill Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_totalSelectedPairs pairs selected',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '₹${_totalPrice.toStringAsFixed(_totalPrice % 1 == 0 ? 0 : 2)}',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _totalSelectedPairs > 0 ? _confirmAddToBill : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                        label: Text(
                          _totalSelectedPairs > 0
                              ? 'Add to Bill ($_totalSelectedPairs)'
                              : 'Select Size(s)',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade500,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
