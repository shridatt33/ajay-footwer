import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/billing_cart_item.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../services/bill_service.dart';
import '../services/local_customer_repository.dart';
import '../services/local_product_repository.dart';
import '../services/shop_profile_repository.dart';
import '../widgets/billing_editable_row.dart';
import '../widgets/billing_invoice_dialog.dart';
import 'customers_screen.dart';
import 'qr_scanner_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final LocalProductRepository _productRepository = LocalProductRepository.instance;
  final LocalCustomerRepository _customerRepository = LocalCustomerRepository.instance;

  final TextEditingController _searchController = TextEditingController();
  // Cart is keyed by "productId_size" so each product+size combo is a separate line.
  final Map<String, BillingCartItem> _cart = <String, BillingCartItem>{};

  // ── Product selection panel state ──────────────────────────────────────────
  // When a product is found via search/QR, it is held here so the user can
  // pick multiple size-quantities before committing to the cart.
  Product? _selectedProduct;
  // Keyed by size string → draft quantity (0 means not selected).
  final Map<String, int> _sizeQtyDraft = {};

  Customer? _selectedCustomer;
  bool _isGeneratingInvoice = false; // prevents duplicate submission

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _surfaceBg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _grandTotal {
    return _cart.values.fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  // ── product panel helpers ──────────────────────────────────────────────────

  /// Opens the size-selection panel for [product].
  /// Reuses existing draft quantities if the same product is already open.
  void _openProductPanel(Product product) {
    setState(() {
      if (_selectedProduct?.productId != product.productId) {
        _sizeQtyDraft.clear();
        for (final size in product.sortedSizes) {
          _sizeQtyDraft[size] = 0;
        }
      }
      _selectedProduct = product;
    });
  }

  /// Dismisses the product panel without adding anything to the cart.
  void _closeProductPanel() {
    setState(() {
      _selectedProduct = null;
      _sizeQtyDraft.clear();
    });
    _searchController.clear();
  }

  /// Commits all draft sizes with qty > 0 into the cart as separate lines.
  void _addDraftToCart() {
    final product = _selectedProduct;
    if (product == null) return;

    final selected = _sizeQtyDraft.entries
        .where((e) => e.value > 0)
        .toList(growable: false);

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one size with quantity > 0.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      for (final entry in selected) {
        final size = entry.key;
        final draftQty = entry.value;
        final cartKey = '${product.productId}_$size';
        final existing = _cart[cartKey];
        if (existing != null) {
          // Merge with existing line of same product+size.
          final merged = existing.quantity + draftQty;
          final capped = merged.clamp(1, existing.availableStock);
          _cart[cartKey] = existing.copyWith(quantity: capped);
        } else {
          _cart[cartKey] = BillingCartItem(
            product: product,
            selectedSize: size,
            quantity: draftQty,
            sellingPrice: product.price,
          );
        }
      }
      _selectedProduct = null;
      _sizeQtyDraft.clear();
    });

    _searchController.clear();
  }

  Future<void> _openCustomerSelection() async {
    final selected = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => const CustomersScreen(isSelectingCustomer: true),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCustomer = selected;
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected Customer: ${selected.name} (${selected.shopName})',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: _primaryRoyalBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _scanQr() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
    );
    if (scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }

    await _addProductById(scannedValue.trim());
  }

  Future<void> _searchProduct() async {
    await _addProductById(_searchController.text.trim());
  }

  Future<void> _addProductById(String productId) async {
    if (productId.isEmpty) return;

    final product = _productRepository.findByProductId(productId);
    if (product == null) {
      await _showMissingProductDialog(productId);
      return;
    }

    if (product.sortedSizes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.productName} has no available sizes.'),
          ),
        );
      }
      _searchController.clear();
      return;
    }

    // Show the size-selection panel — do NOT add directly to cart.
    _openProductPanel(product);
  }

  /// Called by [BillingEditableRow] whenever the user edits price, qty, or size.
  ///
  /// [oldKey] is the key that was in the cart BEFORE the edit.
  /// [updatedItem] carries the new values (including the potentially-changed size).
  void _updateCartItem(String oldKey, BillingCartItem updatedItem) {
    final newKey = '${updatedItem.product.productId}_${updatedItem.selectedSize}';

    setState(() {
      if (newKey == oldKey) {
        // Size did not change — just update in place.
        _cart[newKey] = updatedItem;
      } else {
        // Size changed → remove old line, merge into or create new line.
        _cart.remove(oldKey);
        final existing = _cart[newKey];
        if (existing != null) {
          // Target size already has a line — merge quantities.
          final mergedQty = existing.quantity + updatedItem.quantity;
          final cappedQty = mergedQty.clamp(1, updatedItem.availableStock);
          _cart[newKey] = existing.copyWith(quantity: cappedQty);
        } else {
          _cart[newKey] = updatedItem;
        }
      }
    });
  }

  Future<void> _showMissingProductDialog(String productId) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Product Not Found',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textDark),
          ),
          content: Text(
            'No local product exists for Product ID "$productId".',
            style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRoyalBlue,
                foregroundColor: Colors.white,
              ),
              child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  /// Removes one specific cart line identified by its full key (productId_size).
  void _removeItem(String cartKey) {
    setState(() {
      _cart.remove(cartKey);
    });
  }

  void _clearBill() {
    setState(() {
      _cart.clear();
    });
  }

  void _showNoCustomerAlert() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  color: Colors.orange.shade800,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Customer Required',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ],
          ),
          content: Text(
            'Please select a customer.',
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openCustomerSelection();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRoyalBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(
                'Select Customer Now',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateInvoice() async {
    // Prevent duplicate submissions
    if (_isGeneratingInvoice) return;

    // Rule 1: customer required
    if (_selectedCustomer == null) {
      _showNoCustomerAlert();
      return;
    }

    // Rule 2: cart must not be empty
    if (_cart.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Add products to generate an invoice.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isGeneratingInvoice = true);

    // Snapshot cart and customer now — these are frozen for this invoice.
    final items = _cart.values.toList(growable: false);
    final customer = _selectedCustomer!;
    final priorOutstanding = customer.outstandingBalance;
    final shopProfile = ShopProfileRepository.instance.current;

    // ── Step 1: Save the bill to MongoDB (stock deduction happens server-side).
    // We do this BEFORE showing the dialog so we have a real invoice number.
    // The payment status is determined by the user inside the dialog.
    // We use a neutral placeholder and update it once the user confirms.
    try {
      final savedBill = await BillService.instance.createBill(
        customer: customer,
        cartItems: items,
        shopProfile: shopProfile,
        // Placeholder — will be updated via onDone callback below.
        paymentStatus: 'Pending',
        priorOutstanding: priorOutstanding,
      );

      // Update local product stock cache to reflect server deduction.
      await _productRepository.fetchProducts();

      // Clear the cart now that the bill is saved.
      if (mounted) {
        setState(() {
          _cart.clear();
          _selectedCustomer = customer;
        });
        _searchController.clear();
      }

      if (!mounted) return;

      // ── Step 2: Show the Invoice dialog. The user picks Paid / Add to A/C.
      // The onDone callback fires only when Done is tapped with a valid choice.
      await showDialog<void>(
        context: context,
        barrierDismissible: false, // force explicit Done tap
        builder: (dialogContext) {
          return BillingInvoiceDialog(
            customer: customer,
            invoiceNumber: savedBill.invoiceNo,
            invoiceDate: savedBill.displayDate,
            invoiceCreatedAt: savedBill.createdAt,
            items: items,
            grandTotal: savedBill.grandTotal,
            priorOutstanding: priorOutstanding,
            onDone: (String chosenStatus) async {
              // ── Step 3: Update customer history + outstanding based on choice.
              final itemsSummary = items
                  .map((i) => '${i.product.productName} (${i.quantity} pairs)')
                  .join(', ');

              // Only add to outstanding when the bill is on account.
              final addToOutstanding = chosenStatus == 'Added to A/C';

              await _customerRepository.addInvoiceToCustomer(
                customerId: customer.id,
                invoiceNumber: savedBill.invoiceNo,
                date: savedBill.displayDate,
                // Only add the amount to outstanding for Add to A/C bills.
                amount: addToOutstanding ? savedBill.grandTotal : 0.0,
                status: chosenStatus,
                itemsSummary: itemsSummary,
              );

              // Refresh customer in memory to reflect new outstanding.
              final updatedCustomer =
                  _customerRepository.getCustomerById(customer.id);
              if (mounted && updatedCustomer != null) {
                setState(() => _selectedCustomer = updatedCustomer);
              }
            },
          );
        },
      );
    } catch (e) {
      // Bill save FAILED — cart was NOT cleared.
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save bill: $msg',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingInvoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _cart.values.toList(growable: false);

    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(
          'Billing Counter',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        actions: [
          if (_selectedCustomer != null)
            IconButton(
              icon: const Icon(Icons.person_off_rounded, color: Colors.grey),
              tooltip: 'Deselect Customer',
              onPressed: () {
                setState(() {
                  _selectedCustomer = null;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Customer Selection / Selected Customer Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _selectedCustomer == null
                  ? _buildSelectCustomerCard()
                  : _buildSelectedCustomerCard(),
            ),

            // 2. Search Product ID Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchProduct(),
                style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Search Product ID (e.g. SWA-000004)',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: _primaryRoyalBlue),
                  suffixIcon: IconButton(
                    onPressed: _searchProduct,
                    icon: const Icon(Icons.arrow_forward_rounded, color: _primaryRoyalBlue),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primaryRoyalBlue, width: 1.8),
                  ),
                ),
              ),
            ),

            // OR Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
            ),

            // 3. Scan QR Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: Text(
                    'Scan Product QR Code',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryRoyalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Product size-selection panel (shown when a product is found)
            if (_selectedProduct != null)
              _buildProductPanel(_selectedProduct!),

            // 5. Cart List View
            Expanded(
              child: cartItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Billing Cart is Empty',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Search a Product ID or scan a QR code to add items to bill.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: cartItems.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final cartKey = '${item.product.productId}_${item.selectedSize}';
                        return BillingEditableRow(
                          key: ValueKey<String>(cartKey),
                          item: item,
                          onChanged: (updatedItem) =>
                              _updateCartItem(cartKey, updatedItem),
                          onDelete: () => _removeItem(cartKey),
                        );
                      },
                    ),
            ),

            // 5. Bottom Checkout Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Grand Total',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        '₹${_grandTotal.toStringAsFixed(_grandTotal % 1 == 0 ? 0 : 2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _primaryRoyalBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _cart.isEmpty ? null : _clearBill,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Clear Bill',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _isGeneratingInvoice ? null : _generateInvoice,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryRoyalBlue,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isGeneratingInvoice
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.receipt_long_rounded, size: 18),
                            label: Text(
                              _isGeneratingInvoice ? 'Saving...' : 'Generate Invoice',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  /// Size-selection panel shown after a product is found via search or QR scan.
  Widget _buildProductPanel(Product product) {
    final sizes = product.sortedSizes;
    final price = product.price;
    final selectedCount = _sizeQtyDraft.values.where((q) => q > 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primaryRoyalBlue.withAlpha(60)),
          boxShadow: [
            BoxShadow(
              color: _primaryRoyalBlue.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          '${product.productId}  •  ₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close / dismiss panel
                  IconButton(
                    onPressed: _closeProductPanel,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.grey.shade500,
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),

            const Divider(height: 16, indent: 14, endIndent: 14),

            // ── Size rows ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: sizes.map((size) {
                  final stock = product.sizeStock[size] ?? 0;
                  final qty = _sizeQtyDraft[size] ?? 0;
                  final outOfStock = stock == 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Size chip
                        Container(
                          width: 52,
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 4),
                          decoration: BoxDecoration(
                            color: qty > 0
                                ? _primaryRoyalBlue
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sz $size',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  qty > 0 ? Colors.white : _textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Stock label
                        Expanded(
                          child: Text(
                            outOfStock
                                ? 'Out of stock'
                                : 'Stock: $stock',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: outOfStock
                                  ? Colors.red.shade400
                                  : _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Qty stepper
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: outOfStock || qty <= 0
                                      ? null
                                      : () {
                                          setState(() {
                                            _sizeQtyDraft[size] = qty - 1;
                                          });
                                        },
                                  icon: const Icon(Icons.remove_rounded,
                                      size: 16),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  qty.toString(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: outOfStock || qty >= stock
                                      ? null
                                      : () {
                                          setState(() {
                                            _sizeQtyDraft[size] = qty + 1;
                                          });
                                        },
                                  icon: const Icon(Icons.add_rounded,
                                      size: 16),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ),

            // ── Add to Bill button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: selectedCount > 0 ? _addDraftToCart : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(
                    selectedCount > 0
                        ? 'Add $selectedCount Size${selectedCount > 1 ? 's' : ''} to Bill'
                        : 'Select sizes above',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedCount > 0
                        ? _primaryRoyalBlue
                        : Colors.grey.shade300,
                    foregroundColor: selectedCount > 0
                        ? Colors.white
                        : Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card displayed when NO customer is selected
  Widget _buildSelectCustomerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openCustomerSelection,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: Colors.orange.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Customer',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        'Required before generating invoice',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openCustomerSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRoyalBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  label: Text(
                    'Choose',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

  /// Card displayed when a customer IS selected
  Widget _buildSelectedCustomerCard() {
    final cust = _selectedCustomer!;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryRoyalBlue.withAlpha(80), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _primaryRoyalBlue.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openCustomerSelection,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _primaryRoyalBlue,
                  child: Text(
                    _getInitials(cust.name),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cust.name,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: _primaryRoyalBlue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cust.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _primaryRoyalBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cust.mobile,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _openCustomerSelection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryRoyalBlue,
                    side: const BorderSide(color: _primaryRoyalBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(60, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Change',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'C';
  }
}