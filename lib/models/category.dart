// Named ProductCategory to avoid conflict with Flutter's built-in Category annotation.
class ProductCategory {
  final String id;
  final String name;
  final List<String> sizes;
  final String createdAt;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.sizes,
    required this.createdAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    final rawSizes = json['sizes'];
    final List<String> parsedSizes = rawSizes is List
        ? rawSizes.map((e) => e.toString()).toList()
        : <String>[];
    return ProductCategory(
      id: json['categoryId']?.toString() ?? '',
      name: json['categoryName']?.toString() ?? '',
      sizes: parsedSizes,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryId': id,
        'categoryName': name,
        'sizes': sizes,
      };

  ProductCategory copyWith({String? id, String? name, List<String>? sizes}) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      sizes: sizes ?? List<String>.from(this.sizes),
      createdAt: createdAt,
    );
  }
}
