import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/category_repository.dart';
import '../services/local_product_repository.dart';
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
  bool _isLoading = true;
  String? _errorMessage;

  // Category filter state
  String? _selectedCategoryId; // null = All
  List<ProductCategory> _filterCategories = <ProductCategory>[];

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load both products and categories in parallel
      await Future.wait([
        _repository.fetchProducts(),
        CategoryRepository.instance.fetchCategories(),
      ]);
      if (mounted) {
        setState(() {
          _filterCategories =
              List<ProductCategory>.from(CategoryRepository.instance.currentCategories);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddProductScreen() async {
    final result = await Navigator.of(context).push<Product>(
      MaterialPageRoute<Product>(
        builder: (_) =>
            AddProductScreen(nextSequence: _repository.nextSequence),
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
  }

  Future<void> _editProduct(Product product) async {
    final result = await Navigator.of(context).push<Product>(
      MaterialPageRoute<Product>(
        builder: (_) => AddProductScreen(
          nextSequence: _repository.nextSequence,
          productToEdit: product,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Product?'),
          content: Text(
              'Delete ${product.productName} from persistent inventory database?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _repository.deleteProduct(product.productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: $errorMsg'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _openProductDetails(Product product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _openAddProductScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search product name or Product ID',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),
            ),

            // Category filter chips
            if (_filterCategories.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  children: [
                    // "All" chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          'All',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) {
                          setState(() => _selectedCategoryId = null);
                        },
                        selectedColor:
                            _primaryRoyalBlue.withAlpha(30),
                        checkmarkColor: _primaryRoyalBlue,
                        side: BorderSide(
                          color: _selectedCategoryId == null
                              ? _primaryRoyalBlue
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    // One chip per category
                    ..._filterCategories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            cat.name,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedCategoryId =
                                isSelected ? null : cat.id);
                          },
                          selectedColor:
                              _primaryRoyalBlue.withAlpha(30),
                          checkmarkColor: _primaryRoyalBlue,
                          side: BorderSide(
                            color: isSelected
                                ? _primaryRoyalBlue
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            Expanded(
              child: _buildMainContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products from server...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to Load Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<List<Product>>(
      valueListenable: _repository.products,
      builder: (context, products, _) {
        final filteredProducts = products.where((product) {
          // Category filter
          if (_selectedCategoryId != null &&
              product.categoryId != _selectedCategoryId) {
            return false;
          }

          // Search filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            return product.productName.toLowerCase().contains(query) ||
                product.productId.toLowerCase().contains(query);
          }

          return true;
        }).toList(growable: false);

        if (filteredProducts.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadProducts,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Center(
                    child: Text(
                      _searchQuery.isEmpty && _selectedCategoryId == null
                          ? 'No products available.'
                          : 'No products found.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadProducts,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: filteredProducts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
        );
      },
    );
  }
}
