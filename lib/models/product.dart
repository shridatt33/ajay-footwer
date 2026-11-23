class Product {
  const Product({
    required this.productId,
    required this.productName,
    required this.sizeStock,
    required this.price,
    required this.quantity,
    this.barcode = '',
    required this.qrData,
    required this.createdAt,
    this.categoryId,
    this.categoryName,
  });

  final String productId;
  final String productName;
  final Map<String, int> sizeStock;
  final double price;
  final int quantity;
  final String barcode;
  final String qrData;
  final DateTime createdAt;
  final String? categoryId;
  final String? categoryName;

  String get displayBarcode {
    if (barcode.isNotEmpty) return barcode;
    if (qrData.isNotEmpty) return qrData;
    return productId;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawSizes = json['sizeStock'];
    final parsedSizes = <String, int>{};
    if (rawSizes is Map) {
      rawSizes.forEach((key, value) {
        final parsedValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
        parsedSizes[key.toString()] = parsedValue;
      });
    }

    final quantityValue = json['quantity'];
    final quantity = quantityValue is int
        ? quantityValue
        : int.tryParse(quantityValue?.toString() ?? '') ??
            parsedSizes.values.fold<int>(0, (sum, value) => sum + value);

    final pid = json['productId']?.toString() ?? '';
    final bc = json['barcode']?.toString() ?? json['qrData']?.toString() ?? pid;

    return Product(
      productId: pid,
      productName: json['productName']?.toString() ?? '',
      sizeStock: parsedSizes,
      price: (json['sellingPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0,
      quantity: quantity,
      barcode: bc,
      qrData: bc,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName']?.toString(),
    );
  }

  Product copyWith({
    String? productId,
    String? productName,
    Map<String, int>? sizeStock,
    double? price,
    int? quantity,
    String? barcode,
    String? qrData,
    DateTime? createdAt,
    String? categoryId,
    String? categoryName,
  }) {
    final bc = barcode ?? this.barcode;
    return Product(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sizeStock: sizeStock ?? Map<String, int>.from(this.sizeStock),
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      barcode: bc,
      qrData: qrData ?? (barcode ?? this.qrData),
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productId': productId,
        'productName': productName,
        'sellingPrice': price,
        'sizeStock': Map<String, int>.from(sizeStock),
        'quantity': quantity,
        'barcode': displayBarcode,
        'qrData': displayBarcode,
        'createdAt': createdAt.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryName != null) 'categoryName': categoryName,
      };

  List<String> get sortedSizes {
    final sizes = sizeStock.keys.toList(growable: false);
    sizes.sort((left, right) {
      final leftValue = int.tryParse(left) ?? 0;
      final rightValue = int.tryParse(right) ?? 0;
      return leftValue.compareTo(rightValue);
    });
    return sizes;
  }
}