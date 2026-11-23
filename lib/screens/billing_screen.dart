import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/billing_cart_item.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../services/bill_service.dart';
import '../services/local_customer_repository.dart';
import '../services/local_product_repository.dart';
import '../services/shop_profile_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/billing_invoice_dialog.dart';
import '../widgets/billing_product_group_card.dart';
import '../widgets/multi_size_selection_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'customers_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final LocalProductRepository _repository = LocalProductRepository.instance;
  final LocalCustomerRepository _customerRepository =
      LocalCustomerRepository.instance;
  final ShopProfileRepository _shopProfileRepository =
      ShopProfileRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, BillingCartItem> _cart = <String, BillingCartItem>{};

  Customer? _selectedCustomer;
  bool _isGeneratingInvoice = false;

  String _cartKey(String productId, String size) => '${productId}__$size';

  @override
  void initState() {
    super.initState();
    _repository.fetchProducts();
    _customerRepository.fetchCustomers();
    _shopProfileRepository.fetchProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _grandTotal {
    return _cart.values.fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  int get _totalPairs {
    return _cart.values.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Map<String, List<BillingCartItem>> get _groupedCartItems {
    final map = <String, List<BillingCartItem>>{};
    for (final item in _cart.values) {
      map.putIfAbsent(item.product.productId, () => <BillingCartItem>[]).add(item);
    }
    for (final list in map.values) {
      list.sort((a, b) => (int.tryParse(a.selectedSize) ?? 0).compareTo(int.tryParse(b.selectedSize) ?? 0));
    }
    return map;
  }

  // ── Hardware Barcode Scanner (USB / Bluetooth) ───────────────────────────

  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();

  void _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      final diff = now.difference(_lastKeystrokeTime).inMilliseconds;
      _lastKeystrokeTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final code = _barcodeBuffer.toString().trim();
        _barcodeBuffer.clear();
        if (code.isNotEmpty) {
          _addProductByBarcode(code);
        }
      } else {
        if (diff > 180 && _barcodeBuffer.isNotEmpty) {
          _barcodeBuffer.clear();
        }
        final char = event.character;
        if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
          _barcodeBuffer.write(char);
        }
      }
    }
  }

  // ── Navigation & Actions ─────────────────────────────────────────────────

  Future<void> _scanBarcode() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }

    await _addProductByBarcode(scannedValue.trim());
  }

  Future<void> _searchProduct() async {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      await _addProductByBarcode(query);
    }
  }

  Future<void> _selectCustomer() async {
    final customer = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => const CustomersScreen(isSelectingCustomer: true),
      ),
    );

    if (!mounted || customer == null) {
      return;
    }

    setState(() {
      _selectedCustomer = customer;
    });
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomer = null;
    });
  }

  Future<void> _addProductByBarcode(String barcodeOrCode) async {
    final query = barcodeOrCode.trim();
    if (query.isEmpty) return;

    final product = _repository.findByBarcodeOrId(query);
    if (product == null) {
      await _showMissingProductDialog(query);
      return;
    }

    if (product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add "${product.productName}". Product is out of stock.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _searchController.clear();
      return;
    }

    // Existing quantities of this product currently in the cart
    final existingQuantities = <String, int>{};
    for (final item in _cart.values) {
      if (item.product.productId == product.productId) {
        existingQuantities[item.selectedSize] = item.quantity;
      }
    }

    final selectedSizesToAdd = await MultiSizeSelectionSheet.show(
      context,
      product: product,
      existingCartQuantities: existingQuantities,
    );

    if (selectedSizesToAdd != null && selectedSizesToAdd.isNotEmpty && mounted) {
      int totalAddedPairs = 0;
      setState(() {
        for (final entry in selectedSizesToAdd.entries) {
          final size = entry.key;
          final qty = entry.value;
          final key = _cartKey(product.productId, size);
          final existing = _cart[key];
          final maxStock = product.sizeStock[size] ?? 0;

          if (existing != null) {
            final newQty = (existing.quantity + qty).clamp(1, maxStock);
            _cart[key] = existing.copyWith(quantity: newQty);
            totalAddedPairs += qty;
          } else {
            _cart[key] = BillingCartItem(
              product: product,
              selectedSize: size,
              quantity: qty.clamp(1, maxStock),
              sellingPrice: product.price,
            );
            totalAddedPairs += qty;
          }
        }
      });

      _searchController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $totalAddedPairs pair(s) across ${selectedSizesToAdd.length} size(s) for "${product.productName}".',
            ),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleQuantityChanged(BillingCartItem item, int newQty) {
    final key = _cartKey(item.product.productId, item.selectedSize);
    if (newQty <= 0) {
      setState(() {
        _cart.remove(key);
      });
      return;
    }

    final maxStock = item.availableStock;
    final clamped = newQty.clamp(1, maxStock);
    setState(() {
      _cart[key] = item.copyWith(quantity: clamped);
    });
  }

  void _handleRemoveItem(BillingCartItem item) {
    final key = _cartKey(item.product.productId, item.selectedSize);
    setState(() {
      _cart.remove(key);
    });
  }

  void _removeProduct(String productId) {
    setState(() {
      _cart.removeWhere((_, item) => item.product.productId == productId);
    });
  }

  void _updateProductPrice(Product product, double newPrice) {
    setState(() {
      for (final key in _cart.keys.toList()) {
        final item = _cart[key]!;
        if (item.product.productId == product.productId) {
          _cart[key] = item.copyWith(sellingPrice: newPrice);
        }
      }
    });
  }

  Future<void> _showMissingProductDialog(String barcodeOrId) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Product Not Found'),
            ],
          ),
          content: Text(
            'Unknown Barcode / SKU: "$barcodeOrId".\n\nNo product in inventory matches this code.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _clearBill() {
    if (_cart.isEmpty) return;

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Billing Cart?'),
        content: const Text('Are you sure you want to remove all items from the current bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        setState(() {
          _cart.clear();
          _searchController.clear();
        });
      }
    });
  }

  Future<void> _generateInvoice() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product to generate an invoice.')),
      );
      return;
    }

    final selectedCustomer = _selectedCustomer;
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer before generating the invoice.')),
      );
      return;
    }

    if (_isGeneratingInvoice) {
      return;
    }

    setState(() {
      _isGeneratingInvoice = true;
    });

    final items = _cart.values.toList(growable: false);

    try {
      final bill = await BillService.instance.createBill(
        customer: selectedCustomer,
        cartItems: items,
        shopProfile: _shopProfileRepository.current,
        paymentStatus: 'Paid',
        priorOutstanding: selectedCustomer.outstandingBalance,
      );

      _repository.consumeStockForInvoice(items);
      await _repository.fetchProducts();
      await _customerRepository.fetchCustomers();

      if (!mounted) {
        return;
      }

      setState(() {
        _cart.clear();
        _searchController.clear();
      });

      final refreshed = _customerRepository.getCustomerById(selectedCustomer.id);
      if (refreshed != null) {
        _selectedCustomer = refreshed;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return BillingInvoiceDialog(bill: bill);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingInvoice = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedCartItems;
    final productIds = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'POS Billing',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_cart.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '$_totalPairs pair${_totalPairs > 1 ? 's' : ''}',
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            _handleHardwareKey(event);
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              // ── Main Content Area ───────────────────────────────────────
              Column(
                children: [
                  // 1. Compact Customer Selector
                  _buildCustomerSection(),

                  // 2. Barcode Search & Scan Row
                  _buildSearchAndScanBar(),

                  // 3. Cart Items List
                  Expanded(
                    child: productIds.isEmpty
                        ? _buildEmptyCartView()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
                            itemCount: productIds.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final pid = productIds[index];
                              final items = grouped[pid]!;
                              final product = items.first.product;

                              return BillingProductGroupCard(
                                key: ValueKey<String>(pid),
                                product: product,
                                items: items,
                                onQuantityChanged: _handleQuantityChanged,
                                onRemoveItem: _handleRemoveItem,
                                onRemoveProduct: (p) => _removeProduct(p.productId),
                                onAddMoreSizes: (p) => _addProductByBarcode(p.productId),
                                onPriceChanged: _updateProductPrice,
                              );
                            },
                          ),
                  ),
                ],
              ),

              // ── Sticky Bottom Billing Summary ───────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildStickySummaryBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compact Customer Selection Card ──────────────────────────────────────

  Widget _buildCustomerSection() {
    final customer = _selectedCustomer;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: customer == null ? Colors.white : AppColors.primaryLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: customer == null ? AppColors.border : AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _selectCustomer,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: customer == null ? const Color(0xFFF1F5F9) : AppColors.primary,
                  child: Icon(
                    customer == null ? Icons.person_outline_rounded : Icons.person_rounded,
                    color: customer == null ? AppColors.textSecondary : Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: customer == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Customer / Retailer',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Required for invoice generation',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${customer.mobile} ${customer.shopName.isNotEmpty ? '• ${customer.shopName}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
                if (customer != null)
                  IconButton(
                    onPressed: _clearCustomerSelection,
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Change customer',
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Choose',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Unified Search & Scan Bar ────────────────────────────────────────────

  Widget _buildSearchAndScanBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchProduct(),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Scan or type barcode / SKU...',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.barcode_reader, size: 20),
              label: Text(
                'Scan',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty Cart View ──────────────────────────────────────────────────────

  Widget _buildEmptyCartView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Products in Cart',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scan a product barcode or enter SKU\nto configure sizes and start billing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.barcode_reader, size: 18),
              label: Text(
                'Open Barcode Scanner',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fixed Sticky Bottom Billing Summary ──────────────────────────────────

  Widget _buildStickySummaryBar() {
    final canGenerate = _cart.isNotEmpty && _selectedCustomer != null && !_isGeneratingInvoice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$_totalPairs pair${_totalPairs != 1 ? 's' : ''} in cart',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${_grandTotal.toStringAsFixed(_grandTotal % 1 == 0 ? 0 : 2)}',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Buttons Row
            Row(
              children: [
                // Clear Cart
                OutlinedButton(
                  onPressed: _cart.isEmpty ? null : _clearBill,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: _cart.isEmpty ? Colors.grey.shade300 : AppColors.error.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                  child: const Icon(Icons.delete_sweep_outlined, size: 20),
                ),
                const SizedBox(width: 10),

                // Primary Generate Invoice Button
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canGenerate ? _generateInvoice : null,
                    icon: _isGeneratingInvoice
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.receipt_long_rounded, size: 20),
                    label: Text(
                      _isGeneratingInvoice
                          ? 'Generating Bill...'
                          : _selectedCustomer == null && _cart.isNotEmpty
                              ? 'Select Customer to Bill'
                              : 'Generate Invoice',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
