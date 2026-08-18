import 'product.dart';

class BillingCartItem {
  BillingCartItem({
    required this.product,
    required this.selectedSize,
    required this.quantity,
    required this.sellingPrice,
  });

  final Product product;
  final String selectedSize;
  final int quantity;
  final double sellingPrice;

  BillingCartItem copyWith({
    Product? product,
    String? selectedSize,
    int? quantity,
    double? sellingPrice,
  }) {
    return BillingCartItem(
      product: product ?? this.product,
      selectedSize: selectedSize ?? this.selectedSize,
      quantity: quantity ?? this.quantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
    );
  }

  int get availableStock => product.sizeStock[selectedSize] ?? 0;

  double get lineTotal => sellingPrice * quantity;
}