import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer.dart';
import '../services/local_customer_repository.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customerToEdit;

  const AddEditCustomerScreen({
    super.key,
    this.customerToEdit,
  });

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _shopNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _gstController;
  late TextEditingController _outstandingController;

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _surfaceBg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);

  bool _isSaving = false;

  bool get _isEditing => widget.customerToEdit != null;

  @override
  void initState() {
    super.initState();
    final item = widget.customerToEdit;
    _nameController = TextEditingController(text: item?.name ?? '');
    _shopNameController = TextEditingController(text: item?.shopName ?? '');
    _mobileController = TextEditingController(text: item?.mobile ?? '');
    _emailController = TextEditingController(text: item?.email ?? '');
    _addressController = TextEditingController(text: item?.address ?? '');
    _gstController = TextEditingController(text: item?.gstNumber ?? '');
    _outstandingController = TextEditingController(
      text: item != null && item.outstandingBalance > 0
          ? item.outstandingBalance.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _outstandingController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final repository = LocalCustomerRepository.instance;
    final outstanding =
        double.tryParse(_outstandingController.text.trim()) ?? 0.0;

    try {
      if (_isEditing) {
        final updatedCustomer = widget.customerToEdit!.copyWith(
          name: _nameController.text.trim(),
          shopName: _shopNameController.text.trim(),
          mobile: _mobileController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstController.text.trim(),
          outstandingBalance: outstanding,
        );
        final saved = await repository.updateCustomer(updatedCustomer);
        if (mounted) Navigator.of(context).pop(saved);
      } else {
        // Backend generates the customerId — pass empty id
        final tempCustomer = Customer(
          id: '',
          name: _nameController.text.trim(),
          shopName: _shopNameController.text.trim(),
          mobile: _mobileController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstController.text.trim(),
          outstandingBalance: outstanding,
          totalBills: 0,
          purchaseHistory: const [],
        );
        final saved = await repository.addCustomer(tempCustomer);
        if (mounted) Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Customer' : 'Add New Customer',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_add_rounded,
                            size: 20,
                            color: _primaryRoyalBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Information',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),

                      // 1. Customer Name
                      _buildFormField(
                        controller: _nameController,
                        label: 'Customer Name *',
                        hint: 'e.g. Rajesh Sharma',
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter customer name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. Shop Name
                      _buildFormField(
                        controller: _shopNameController,
                        label: 'Shop Name *',
                        hint: 'e.g. Metro Footwear',
                        icon: Icons.storefront_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter shop name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 3. Mobile Number
                      _buildFormField(
                        controller: _mobileController,
                        label: 'Mobile Number *',
                        hint: 'e.g. +91 98220 12345',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 4. Email Address
                      _buildFormField(
                        controller: _emailController,
                        label: 'Email Address (Optional)',
                        hint: 'e.g. customer@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      // 5. GST Number
                      _buildFormField(
                        controller: _gstController,
                        label: 'GST Number (Optional)',
                        hint: 'e.g. 27AABCM1234A1Z2',
                        icon: Icons.receipt_long_outlined,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 14),

                      // 6. Address
                      _buildFormField(
                        controller: _addressController,
                        label: 'Shop Address *',
                        hint: 'e.g. Shop 14, Main Market, Kolhapur',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter shop address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 7. Opening Balance
                      _buildFormField(
                        controller: _outstandingController,
                        label: 'Opening Outstanding Balance (₹)',
                        hint: 'e.g. 15000',
                        icon: Icons.account_balance_wallet_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryRoyalBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Icon(
                            _isEditing
                                ? Icons.check_circle_rounded
                                : Icons.add_business_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : (_isEditing ? 'Update Customer' : 'Save Customer'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: Icon(icon, size: 20, color: _primaryRoyalBlue),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryRoyalBlue, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
