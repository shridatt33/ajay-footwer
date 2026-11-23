import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/local_product_repository.dart';
import '../theme/app_theme.dart';

class PurchaseEntryScreen extends StatefulWidget {
  const PurchaseEntryScreen({super.key});

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final LocalProductRepository _productRepository = LocalProductRepository.instance;
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController(text: 'Walkmate Industries');
  
  Product? _selectedProduct;
  final Map<String, TextEditingController> _sizeControllers = {};
  final TextEditingController _costRateController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productRepository.fetchProducts().then((_) {
      if (mounted && _selectedProduct == null && _productRepository.currentProducts.isNotEmpty) {
        _selectProduct(_productRepository.currentProducts.first);
      }
    });
    final products = _productRepository.currentProducts;
    if (products.isNotEmpty) {
      _selectProduct(products.first);
    }
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _supplierController.dispose();
    _costRateController.dispose();
    for (final c in _sizeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _sizeControllers.clear();
      for (final sizeKey in product.sizeStock.keys) {
        _sizeControllers[sizeKey] = TextEditingController(text: '0');
      }
    });
  }

  int get _totalInwardQuantity {
    var sum = 0;
    for (final c in _sizeControllers.values) {
      sum += int.tryParse(c.text.trim()) ?? 0;
    }
    return sum;
  }

  double get _totalInwardCost {
    final rate = double.tryParse(_costRateController.text.trim()) ?? 0.0;
    return _totalInwardQuantity * rate;
  }

  Future<void> _submitInwardStock() async {
    if (_selectedProduct == null) return;
    if (_totalInwardQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter quantity for at least one size.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedStock = Map<String, int>.from(_selectedProduct!.sizeStock);
      for (final entry in _sizeControllers.entries) {
        final addQty = int.tryParse(entry.value.text.trim()) ?? 0;
        final current = updatedStock[entry.key] ?? 0;
        updatedStock[entry.key] = current + addQty;
      }

      final newTotalQty = updatedStock.values.fold<int>(0, (sum, val) => sum + val);
      final updatedProduct = _selectedProduct!.copyWith(
        sizeStock: updatedStock,
        quantity: newTotalQty,
      );

      await _productRepository.updateProduct(updatedProduct);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added $_totalInwardQuantity pairs to ${_selectedProduct!.productName}!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _productRepository.currentProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase Inward Entry'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Inward header details
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supplier & Invoice',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier / Manufacturer Name',
                        prefixIcon: Icon(Icons.business_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _invoiceController,
                            decoration: const InputDecoration(
                              labelText: 'Challan / Bill No.',
                              hintText: 'e.g. INV-9042',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Today',
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Product Picker
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppDecorations.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Footwear Item',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Product>(
                      initialValue: _selectedProduct,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                      ),
                      items: products.map((p) {
                        return DropdownMenuItem<Product>(
                          value: p,
                          child: Text('${p.productName} (${p.displayBarcode})'),
                        );
                      }).toList(),
                      onChanged: (p) {
                        if (p != null) _selectProduct(p);
                      },
                    ),
                    if (_selectedProduct != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Current Stock: ${_selectedProduct!.quantity} pairs',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Selling MRP: ₹${_selectedProduct!.price.toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Size breakdown input
              if (_selectedProduct != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Size-wise Inward Quantity',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Total Pairs: $_totalInwardQuantity',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _sizeControllers.length,
                        itemBuilder: (context, index) {
                          final sizeKey = _sizeControllers.keys.elementAt(index);
                          final controller = _sizeControllers[sizeKey]!;
                          final currentQty = _selectedProduct!.sizeStock[sizeKey] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Size $sizeKey (Curr: $currentQty)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _costRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Rate / Pair (₹)',
                          hintText: 'e.g. 180',
                          prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Inward Summary & Submit
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.card(color: AppColors.primaryLight, border: Border.all(color: const Color(0xFFBFDBFE))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Inward Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(
                            '$_totalInwardQuantity pairs',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ],
                      ),
                      if (_costRateController.text.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Estimated Cost', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Text(
                              '₹${_totalInwardCost.toStringAsFixed(0)}',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _submitInwardStock,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Purchase Inward'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
