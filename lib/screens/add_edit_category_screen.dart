import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/category.dart';
import '../services/category_repository.dart';

class AddEditCategoryScreen extends StatefulWidget {
  const AddEditCategoryScreen({
    super.key,
    this.categoryToEdit,
  });

  final ProductCategory? categoryToEdit;

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  static const List<String> _allSizes = <String>[
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  ];

  final Set<String> _selectedSizes = <String>{};
  bool _isSaving = false;

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color.fromARGB(255, 111, 150, 189);

  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final cat = widget.categoryToEdit!;
      _nameController.text = cat.name;
      _selectedSizes.addAll(cat.sizes);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleSize(String size) {
    setState(() {
      if (_selectedSizes.contains(size)) {
        _selectedSizes.remove(size);
      } else {
        _selectedSizes.add(size);
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade700 : _primaryRoyalBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSizes.isEmpty) {
      _showSnackBar('Please select at least one size.', isError: true);
      return;
    }

    // Maintain the order of _allSizes when saving
    final orderedSizes = _allSizes
        .where((s) => _selectedSizes.contains(s))
        .toList();

    setState(() => _isSaving = true);

    try {
      final ProductCategory saved;
      if (_isEditing) {
        final updated = widget.categoryToEdit!.copyWith(
          name: _nameController.text.trim(),
          sizes: orderedSizes,
        );
        saved = await CategoryRepository.instance.updateCategory(updated);
      } else {
        final newCat = ProductCategory(
          id: '',
          name: _nameController.text.trim(),
          sizes: orderedSizes,
          createdAt: '',
        );
        saved = await CategoryRepository.instance.addCategory(newCat);
      }
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        _showSnackBar(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEditing ? 'Edit Category' : 'Add Category';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          titleText,
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w600, color: _textDark),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _primaryRoyalBlue),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
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
                        color: const Color(0xFF1565C0).withValues(alpha: 0.20),
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
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isEditing
                            ? 'Update the category name and available sizes.'
                            : 'Create a product category and define available sizes.',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form card
                Card(
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Category Name
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: _textDark),
                          decoration: InputDecoration(
                            labelText: 'Category Name *',
                            hintText: 'e.g. Men\'s Casual, Kids Sports',
                            prefixIcon: const Icon(Icons.category_outlined),
                            labelStyle:
                                GoogleFonts.poppins(color: _textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Category name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Sizes selection
                        FormField<Set<String>>(
                          validator: (_) {
                            if (_selectedSizes.isEmpty) {
                              return 'Select at least one size';
                            }
                            return null;
                          },
                          builder: (fieldState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Sizes *',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choose which sizes are available for this category.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _allSizes.map((size) {
                                    final isSelected =
                                        _selectedSizes.contains(size);
                                    return FilterChip(
                                      selected: isSelected,
                                      label: Text(
                                        'Size $size',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onSelected: (_) => _toggleSize(size),
                                      selectedColor:
                                          _primaryRoyalBlue.withAlpha(30),
                                      checkmarkColor: _primaryRoyalBlue,
                                      side: BorderSide(
                                        color: isSelected
                                            ? _primaryRoyalBlue
                                            : Colors.grey.shade300,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (fieldState.hasError) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    fieldState.errorText ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Save button
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryRoyalBlue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : (_isEditing
                                      ? 'Update Category'
                                      : 'Save Category'),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
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
}
