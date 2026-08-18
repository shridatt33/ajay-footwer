import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/billing_cart_item.dart';

class BillingEditableRow extends StatefulWidget {
  const BillingEditableRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final BillingCartItem item;
  final ValueChanged<BillingCartItem> onChanged;
  final VoidCallback onDelete;

  @override
  State<BillingEditableRow> createState() => _BillingEditableRowState();
}

class _BillingEditableRowState extends State<BillingEditableRow> {
  late final TextEditingController _priceController;
  late final FocusNode _priceFocusNode;
  late String _selectedSize;
  late int _quantity;
  String? _quantityError;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.item.selectedSize;
    _quantity = widget.item.quantity;
    _priceController = TextEditingController(text: _formatPrice(widget.item.sellingPrice));
    _priceFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant BillingEditableRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When the parent swaps in a new item (e.g. after a size-change key remap),
    // sync local state with the incoming item values.
    final newItem = widget.item;
    final oldItem = oldWidget.item;

    if (oldItem.product.productId != newItem.product.productId ||
        oldItem.selectedSize != newItem.selectedSize) {
      _selectedSize = newItem.selectedSize;
      _quantity = newItem.quantity;
      _quantityError = null;
      _priceController.text = _formatPrice(newItem.sellingPrice);
      return;
    }

    if (!_priceFocusNode.hasFocus) {
      final formattedPrice = _formatPrice(newItem.sellingPrice);
      if (_priceController.text != formattedPrice) {
        _priceController.text = formattedPrice;
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(price % 1 == 0 ? 0 : 2);
  }

  String _currency(double price) {
    return '₹${_formatPrice(price)}';
  }

  int get _availableStock => widget.item.product.sizeStock[_selectedSize] ?? 0;

  void _emitChange({double? sellingPrice}) {
    widget.onChanged(
      widget.item.copyWith(
        selectedSize: _selectedSize,
        quantity: _quantity,
        sellingPrice: sellingPrice ?? widget.item.sellingPrice,
      ),
    );
  }

  void _handlePriceChanged(String value) {
    final price = double.tryParse(value.trim());
    if (price == null || price <= 0) {
      return;
    }

    _emitChange(sellingPrice: price);
  }

  void _handleSizeChanged(String? size) {
    if (size == null || size == _selectedSize) {
      return;
    }

    setState(() {
      _selectedSize = size;
      final stock = _availableStock;
      if (_quantity > stock) {
        _quantity = stock;
        _quantityError = 'Quantity cannot exceed available stock.';
      } else {
        _quantityError = null;
      }
    });

    _emitChange();
  }

  void _increaseQuantity() {
    if (_quantity >= _availableStock) {
      setState(() {
        _quantityError = 'Quantity cannot exceed available stock.';
      });
      return;
    }

    setState(() {
      _quantity += 1;
      _quantityError = null;
    });
    _emitChange();
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) {
      return;
    }

    setState(() {
      _quantity -= 1;
      _quantityError = null;
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableSizes = widget.item.product.sortedSizes;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    children: [
                      Text(
                        widget.item.product.productName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.product.productId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete item',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(
                      labelText: 'Selling Price',
                      prefixText: '₹ ',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: _handlePriceChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(_selectedSize),
                    initialValue: _selectedSize,
                    decoration: InputDecoration(
                      labelText: 'Size',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: availableSizes
                        .map(
                          (size) => DropdownMenuItem<String>(
                            value: size,
                            child: Text('Size $size'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _handleSizeChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Stock',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _availableStock.toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1 ? _decreaseQuantity : null,
                        icon: const Icon(Icons.remove_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          _quantity.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _quantity < _availableStock ? _increaseQuantity : null,
                        icon: const Icon(Icons.add_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Line Total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currency(widget.item.sellingPrice * _quantity),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_quantityError != null) ...[
              const SizedBox(height: 8),
              Text(
                _quantityError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}