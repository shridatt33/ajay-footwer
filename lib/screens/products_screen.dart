import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/local_product_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/product_list_row.dart';
import 'add_product_screen.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final LocalProductRepository _repository = LocalProductRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository.fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _openAddProductScreen() async {
    final result = await Navigator.of(context).push<Product>(
      MaterialPageRoute<Product>(
        builder: (_) => AddProductScreen(nextSequence: _repository.nextSequence),
      ),
    );

    if (!mounted || result == null) {
      return;
    }
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    _showSnackBar('Product "${result.productName}" added successfully.');
  }

  Future<void> _editProduct(Product product) async {
    final updated = await Navigator.of(context).push<Product>(
      MaterialPageRoute<Product>(
        builder: (_) => AddProductScreen(
          nextSequence: _repository.nextSequence,
          productToEdit: product,
        ),
      ),
    );

    if (updated != null && mounted) {
      _showSnackBar('Updated "${updated.productName}" details.');
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Product',
              style: TextStyle(fontFamily: 'Poppins', 
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Delete "${product.productName}" (${product.productId}) from inventory? This cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _repository.deleteProduct(product.productId);
      _showSnackBar('Deleted "${product.productName}".');
    }
  }

  Future<void> _openProductDetails(Product product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Products',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openAddProductScreen,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Add',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProductScreen,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_box_rounded, size: 20),
        label: Text(
          'Add Product',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search product name or Product ID / Barcode...',
                    hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                    });
                  },
                ),
              ),
            ),

            // ── Product List & Summary ───────────────────────────────────
            Expanded(
              child: ValueListenableBuilder<List<Product>>(
                valueListenable: _repository.products,
                builder: (context, products, _) {
                  final filteredProducts = products.where((product) {
                    if (_searchQuery.isEmpty) {
                      return true;
                    }

                    final query = _searchQuery.toLowerCase();
                    return product.productName.toLowerCase().contains(query) ||
                        product.productId.toLowerCase().contains(query) ||
                        product.displayBarcode.toLowerCase().contains(query);
                  }).toList(growable: false);

                  if (products.isEmpty) {
                    return _buildEmptyState();
                  }

                  if (filteredProducts.isEmpty) {
                    return _buildNoResultsState(_searchQuery);
                  }

                  final totalStock = products.fold<int>(0, (sum, p) => sum + p.quantity);

                  return Column(
                    children: [
                      // Summary Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              'Total Products: ${products.length}',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '$totalStock pairs in stock',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Products List View
                      Expanded(
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ProductListRow(
                              product: product,
                              onTap: () => _openProductDetails(product),
                              onEditPressed: () => _editProduct(product),
                              onDeletePressed: () => _deleteProduct(product),
                              onQrPressed: () => _openProductDetails(product),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Products in Catalog',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your footwear products to start managing stock and barcode billing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openAddProductScreen,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_box_rounded, size: 18),
              label: Text(
                'Add First Product',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 30, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              'No Products Match "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with a different name, SKU, or Barcode.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
