import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProductForm extends StatelessWidget {
  const ProductForm({
    super.key,
    required this.formKey,
    required this.productNameController,
    required this.priceController,
    required this.selectedSizes,
    required this.quantityControllers,
    required this.availableSizes,
    required this.onToggleSize,
    required this.onSave,
    required this.onCancel,
    required this.isSaving,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController productNameController;
  final TextEditingController priceController;
  final Set<String> selectedSizes;
  final Map<String, TextEditingController> quantityControllers;
  final List<String> availableSizes;
  final ValueChanged<String> onToggleSize;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: productNameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Product Name *',
              hintText: 'Enter product name',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Product name is required';
              }
              return null;
            },
          ),
          SizedBox(height: spacing + 6),
          FormField<Set<String>>(
            validator: (_) {
              if (selectedSizes.isEmpty) {
                return 'Select at least one size';
              }
              return null;
            },
            builder: (fieldState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Sizes *',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableSizes.map((size) {
                      final isSelected = selectedSizes.contains(size);
                      return FilterChip(
                        selected: isSelected,
                        label: Text('Size $size'),
                        onSelected: (_) => onToggleSize(size),
                        avatar: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          size: 18,
                        ),
                      );
                    }).toList(),
                  ),
                  if (fieldState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        fieldState.errorText ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (selectedSizes.isEmpty)
                    Text(
                      'Select at least one size to enter stock quantities.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    )
                  else
                    Column(
                      children: availableSizes.where(selectedSizes.contains).map((size) {
                        final controller = quantityControllers[size];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 56,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.straighten_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Size $size'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  key: ValueKey('quantity-$size'),
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    labelText: 'Quantity *',
                                    hintText: '0',
                                    prefixIcon: const Icon(Icons.numbers_rounded),
                                    helperText: 'Required',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Quantity required';
                                    }
                                    final quantity = int.tryParse(text);
                                    if (quantity == null || quantity <= 0) {
                                      return 'Enter a valid quantity';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
          SizedBox(height: spacing + 6),
          TextFormField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'Selling Price *',
              hintText: '0.00',
              prefixIcon: Icon(Icons.payments_outlined),
              prefixText: '₹ ',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) {
                return 'Selling price is required';
              }
              final price = double.tryParse(text);
              if (price == null || price <= 0) {
                return 'Enter a valid price';
              }
              return null;
            },
          ),
          SizedBox(height: spacing * 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 360;
              final saveButton = FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save Product'),
              );
              final cancelButton = OutlinedButton.icon(
                onPressed: isSaving ? null : onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: saveButton),
                    const SizedBox(width: 12),
                    Expanded(child: cancelButton),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  saveButton,
                  const SizedBox(height: 12),
                  cancelButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}