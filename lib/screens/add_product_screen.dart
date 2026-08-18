import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/category_repository.dart';
import '../services/local_product_repository.dart';
import '../services/qr_generator.dart';
import '../widgets/product_form.dart';
import '../widgets/qr_dialog.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
    required this.nextSequence,
    this.productToEdit,
  });

  final int nextSequence;
  final Product? productToEdit;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final QrGeneratorService _qrGeneratorService = const QrGeneratorService();
  final Map<String, TextEditingController> _quantityControllers =
      <String, TextEditingController>{};

  final Set<String> _selectedSizes = <String>{};
  bool _isSaving = false;

  // Category state
  List<ProductCategory> _categories = <ProductCategory>[];
  ProductCategory? _selectedCategory;
  bool _loadingCategories = true;

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  bool get _isEditing => widget.productToEdit != null;

  List<String> get _availableSizes =>
      _selectedCategory?.sizes ?? <String>[];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) {
      final p = widget.productToEdit!;
      _productNameController.text = p.productName;
      _priceController.text =
          p.price.toStringAsFixed(p.price % 1 == 0 ? 0 : 2);
      p.sizeStock.forEach((size, qty) {
        _selectedSizes.add(size);
        _quantityControllers[size] =
            TextEditingController(text: qty.toString());
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      await CategoryRepository.instance.fetchCategories();
      if (!mounted) return;
      final cats = CategoryRepository.instance.currentCategories;
      setState(() {
        _categories = cats;
        _loadingCategories = false;

        // When editing, find the matching category
        if (_isEditing && widget.productToEdit!.categoryId != null) {
          final catId = widget.productToEdit!.categoryId!;
          try {
            _selectedCategory = _categories.firstWhere((c) => c.id == catId);
          } catch (_) {
            _selectedCategory = null;
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _categories = CategoryRepository.instance.currentCategories;
          _loadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _priceController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleSize(String size) {
    if (_selectedSizes.contains(size)) {
      setState(() {
        _selectedSizes.remove(size);
        _quantityControllers.remove(size)?.dispose();
      });
      return;
    }

    setState(() {
      _selectedSizes.add(size);
      _quantityControllers[size] = TextEditingController();
    });
  }

  Future<void> _saveProduct() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a category.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one size.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final Map<String, int> sizeStock = <String, int>{};
    for (final size in _selectedSizes) {
      final quantityText = _quantityControllers[size]?.text.trim() ?? '';
      final quantity = int.tryParse(quantityText);
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter a valid quantity for size $size.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      sizeStock[size] = quantity;
    }

    final productName = _productNameController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final quantity =
        sizeStock.values.fold<int>(0, (sum, value) => sum + value);
    final productId = _isEditing
        ? widget.productToEdit!.productId
        : _qrGeneratorService.generateProductId(widget.nextSequence);
    final qrData = _isEditing
        ? widget.productToEdit!.qrData
        : _qrGeneratorService.buildQrData(productId);

    final product = Product(
      productId: productId,
      productName: productName,
      sizeStock: sizeStock,
      price: price,
      quantity: quantity,
      qrData: qrData,
      createdAt:
          _isEditing ? widget.productToEdit!.createdAt : DateTime.now(),
      categoryId: _selectedCategory?.id,
      categoryName: _selectedCategory?.name,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        final updated =
            await LocalProductRepository.instance.updateProduct(product);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product updated successfully.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: _primaryRoyalBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop(updated);
      } else {
        final saved =
            await LocalProductRepository.instance.addProduct(product);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product added successfully.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: _primaryRoyalBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );

        await showDialog<void>(
          context: context,
          builder: (context) {
            return QrDialog(
              productId: saved.productId,
              productName: saved.productName,
              qrData: saved.qrData,
              onDownload: () async {
                await _qrGeneratorService.saveQrImageToDocuments(
                  qrData: saved.qrData,
                  productId: saved.productId,
                );
              },
              onPrint: () async {
                await _qrGeneratorService.printQrCode(
                  qrData: saved.qrData,
                  productId: saved.productId,
                );
              },
            );
          },
        );

        if (mounted) {
          Navigator.of(context).pop(saved);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEditing ? 'Edit Product' : 'Add Product';
    final subtitleText = _isEditing
        ? 'Update product details, pricing, and stock in the central inventory database.'
        : 'Create inventory items for wholesale footwear and generate a QR code from the Product ID only.';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF1565C0).withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitleText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category selector card
              Card(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCategorySection(),
                ),
              ),
              const SizedBox(height: 12),

              // Product form card
              Card(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ProductForm(
                    formKey: _formKey,
                    productNameController: _productNameController,
                    priceController: _priceController,
                    selectedSizes: _selectedSizes,
                    quantityControllers: _quantityControllers,
                    availableSizes: _availableSizes,
                    onToggleSize: _toggleSize,
                    onSave: _saveProduct,
                    onCancel: _cancel,
                    isSaving: _isSaving,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // QR info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How QR Codes Work',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Only the unique Product ID is stored in the QR code. Product name, size, price, and quantity stay in the local product object.',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading categories...'),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category *',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFFCC02).withAlpha(120)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF57F17), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No categories found. Add categories from Profile > Settings > Categories.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF795548),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<ProductCategory>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        prefixIcon: const Icon(Icons.category_outlined),
        labelStyle: GoogleFonts.poppins(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      hint: Text(
        'Select a category',
        style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary),
      ),
      items: _categories.map((cat) {
        return DropdownMenuItem<ProductCategory>(
          value: cat,
          child: Text(
            cat.name,
            style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
          ),
        );
      }).toList(),
      onChanged: (ProductCategory? cat) {
        setState(() {
          _selectedCategory = cat;
          // Clear size selections since available sizes may change
          for (final ctrl in _quantityControllers.values) {
            ctrl.dispose();
          }
          _quantityControllers.clear();
          _selectedSizes.clear();
        });
      },
      validator: (value) {
        if (value == null) return 'Please select a category';
        return null;
      },
    );
  }
}
