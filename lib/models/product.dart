class Product {
  const Product({
    required this.productId,
    required this.productName,
    required this.sizeStock,
    required this.price,
    required this.quantity,
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
  final String qrData;
  final DateTime createdAt;
  final String? categoryId;
  final String? categoryName;

  Product copyWith({
    String? productId,
    String? productName,
    Map<String, int>? sizeStock,
    double? price,
    int? quantity,
    String? qrData,
    DateTime? createdAt,
    String? categoryId,
    String? categoryName,
  }) {
    return Product(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sizeStock: sizeStock ?? Map<String, int>.from(this.sizeStock),
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      qrData: qrData ?? this.qrData,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final sizeStockMap = <String, int>{};
    if (json['sizeStock'] is Map) {
      (json['sizeStock'] as Map).forEach((key, value) {
        if (value is num) {
          sizeStockMap[key.toString()] = value.toInt();
        } else if (value is String) {
          sizeStockMap[key.toString()] = int.tryParse(value) ?? 0;
        }
      });
    }

    final price = (json['sellingPrice'] ?? json['price'] ?? 0).toDouble();
    final quantity = json['quantity'] != null
        ? (json['quantity'] as num).toInt()
        : sizeStockMap.values.fold<int>(0, (sum, val) => sum + val);

    final pName = (json['productName'] ?? json['name'] ?? '').toString();

    final rawPid = json['productId']?.toString() ?? '';
    final pid = rawPid.isNotEmpty ? rawPid : 'SWA-000001';

    final catId = json['categoryId']?.toString();
    final catName = json['categoryName']?.toString();

    return Product(
      productId: pid,
      productName: pName,
      sizeStock: sizeStockMap,
      price: price,
      quantity: quantity,
      qrData: json['qrData']?.toString() ?? json['productId']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      categoryId: (catId != null && catId.isNotEmpty) ? catId : null,
      categoryName: (catName != null && catName.isNotEmpty) ? catName : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'sellingPrice': price,
      'price': price,
      'sizeStock': sizeStock,
      'quantity': quantity,
      'qrData': qrData,
      'createdAt': createdAt.toIso8601String(),
    };
    if (categoryId != null && categoryId!.isNotEmpty) {
      map['categoryId'] = categoryId;
    }
    if (categoryName != null && categoryName!.isNotEmpty) {
      map['categoryName'] = categoryName;
    }
    return map;
  }

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
