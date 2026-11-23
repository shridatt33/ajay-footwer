import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/barcode_service.dart';
import '../services/local_product_repository.dart';
import '../services/shop_profile_repository.dart';

class BarcodeStudioScreen extends StatefulWidget {
  const BarcodeStudioScreen({super.key});

  @override
  State<BarcodeStudioScreen> createState() => _BarcodeStudioScreenState();
}

class _BarcodeStudioScreenState extends State<BarcodeStudioScreen> {
  final LocalProductRepository _productRepository = LocalProductRepository.instance;
  final ShopProfileRepository _shopProfileRepository = ShopProfileRepository.instance;
  final BarcodeService _barcodeService = BarcodeService.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedProductIds = <String>{};
  final Map<String, int> _printCopies = <String, int>{};
  Product? _previewProduct;
  bool _isPrinting = false;

  static const Color _primaryColor = Color(0xFF1565C0);
  static const Color _surfaceBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    final allProducts = _productRepository.currentProducts;
    if (allProducts.isNotEmpty) {
      _previewProduct = allProducts.first;
      for (final p in allProducts) {
        _printCopies[p.productId] = 1;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final all = _productRepository.currentProducts;
    if (query.isEmpty) return all;
    return all.where((p) {
      return p.productName.toLowerCase().contains(query) ||
          p.productId.toLowerCase().contains(query) ||
          p.displayBarcode.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSelectAll(bool? select) {
    setState(() {
      if (select == true) {
        _selectedProductIds.addAll(_filteredProducts.map((p) => p.productId));
      } else {
        _selectedProductIds.clear();
      }
    });
  }

  Future<void> _printSelectedBulk() async {
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one product for bulk printing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPrinting = true);
    try {
      final selectedProducts = <Product>[];
      final all = _productRepository.currentProducts;
      for (final p in all) {
        if (_selectedProductIds.contains(p.productId)) {
          final copies = _printCopies[p.productId] ?? 1;
          for (var i = 0; i < copies; i++) {
            selectedProducts.add(p);
          }
        }
      }

      final shopName = _shopProfileRepository.current.shopName.isNotEmpty
          ? _shopProfileRepository.current.shopName
          : 'Swamidatta Agencies';

      await _barcodeService.printBarcodeSheet(
        products: selectedProducts,
        copiesPerProduct: 1,
        shopName: shopName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing barcode sheet: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _printSingle(Product product) async {
    setState(() => _isPrinting = true);
    try {
      final shopName = _shopProfileRepository.current.shopName.isNotEmpty
          ? _shopProfileRepository.current.shopName
          : 'Swamidatta Agencies';
      await _barcodeService.printSingleBarcode(product, shopName: shopName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing sticker: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _downloadSingle(Product product) async {
    try {
      final shopName = _shopProfileRepository.current.shopName.isNotEmpty
          ? _shopProfileRepository.current.shopName
          : 'Swamidatta Agencies';
      await _barcodeService.saveBarcodeLabelToGallery(product, shopName: shopName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barcode sticker saved successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final allSelected = filtered.isNotEmpty && _selectedProductIds.length == filtered.length;
    final shopName = _shopProfileRepository.current.shopName.isNotEmpty
        ? _shopProfileRepository.current.shopName
        : 'Swamidatta Agencies';

    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        title: Text(
          'Barcode Studio',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _textDark),
        ),
        actions: [
          if (_selectedProductIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _isPrinting ? null : _printSelectedBulk,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: Text('Print (${_selectedProductIds.length})'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview Card at Top
            if (_previewProduct != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sticker Preview (Code 128)',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Download sticker',
                              icon: const Icon(Icons.download_rounded, size: 20),
                              onPressed: () => _downloadSingle(_previewProduct!),
                            ),
                            IconButton(
                              tooltip: 'Print single sticker',
                              icon: const Icon(Icons.print_rounded, size: 20),
                              onPressed: () => _printSingle(_previewProduct!),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Label Box Mockup
                    Center(
                      child: Container(
                        width: 290,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Text(
                              shopName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _previewProduct!.productName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: _previewProduct!.displayBarcode,
                              width: 240,
                              height: 62,
                              drawText: true,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SKU: ${_previewProduct!.productId}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'MRP: ₹${_previewProduct!.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Search Bar & Multi-Select Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search product name, code, or barcode',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Select All & Bulk Print Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    activeColor: _primaryColor,
                    onChanged: _toggleSelectAll,
                  ),
                  Text(
                    'Select All (${filtered.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_selectedProductIds.isNotEmpty)
                    Text(
                      '${_selectedProductIds.length} selected',
                      style: const TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),

            // Product List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No products match your search.',
                        style: TextStyle(fontFamily: 'Poppins', color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final isSelected = _selectedProductIds.contains(product.productId);
                        final isPreview = _previewProduct?.productId == product.productId;
                        final copies = _printCopies[product.productId] ?? 1;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPreview
                                  ? _primaryColor
                                  : (isSelected ? _primaryColor.withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
                              width: isPreview ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => setState(() => _previewProduct = product),
                            leading: Checkbox(
                              value: isSelected,
                              activeColor: _primaryColor,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProductIds.add(product.productId);
                                  } else {
                                    _selectedProductIds.remove(product.productId);
                                  }
                                });
                              },
                            ),
                            title: Text(
                              product.productName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  'Barcode: ${product.displayBarcode}  •  SKU: ${product.productId}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'MRP: ₹${product.price.toStringAsFixed(0)}  •  Stock: ${product.quantity}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                  onPressed: copies > 1
                                      ? () => setState(() => _printCopies[product.productId] = copies - 1)
                                      : null,
                                ),
                                Text(
                                  '$copies',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                  onPressed: () =>
                                      setState(() => _printCopies[product.productId] = copies + 1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
