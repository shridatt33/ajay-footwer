/// Represents a persisted bill document from ajayfw.bills (MongoDB).
class BillItem {
  final String productId;
  final String productName;
  final String size;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const BillItem({
    required this.productId,
    required this.productName,
    required this.size,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ??
          (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'size': size,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };
}

class BillBusinessProfile {
  final String shopName;
  final String ownerName;
  final String mobile;
  final String email;
  final String gstNumber;
  final String address;

  const BillBusinessProfile({
    required this.shopName,
    required this.ownerName,
    required this.mobile,
    required this.email,
    required this.gstNumber,
    required this.address,
  });

  factory BillBusinessProfile.fromJson(Map<String, dynamic> json) {
    return BillBusinessProfile(
      shopName: json['shopName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      mobile: json['mobileNumber']?.toString() ??
          json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gstNumber: json['gstNumber']?.toString() ?? '',
      address: json['shopAddress']?.toString() ??
          json['address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'ownerName': ownerName,
        'mobileNumber': mobile,
        'email': email,
        'gstNumber': gstNumber,
        'shopAddress': address,
      };

  static const BillBusinessProfile empty = BillBusinessProfile(
    shopName: '', ownerName: '', mobile: '',
    email: '', gstNumber: '', address: '',
  );
}

class Bill {
  final String invoiceNo;
  final String customerId;
  final String customerName;
  final String customerShopName;
  final String customerMobile;
  final List<BillItem> products;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final String status;
  final BillBusinessProfile businessProfile;
  final String createdAt;
  /// Customer's outstanding balance BEFORE this bill was created.
  /// Stored in the bill document so reprints always show the correct snapshot.
  final double priorOutstanding;

  const Bill({
    required this.invoiceNo,
    required this.customerId,
    required this.customerName,
    required this.customerShopName,
    required this.customerMobile,
    required this.products,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.grandTotal,
    required this.status,
    required this.businessProfile,
    required this.createdAt,
    this.priorOutstanding = 0.0,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final List<BillItem> items = rawProducts is List
        ? rawProducts
            .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <BillItem>[];

    final rawBp = json['businessProfile'];
    final bp = rawBp is Map<String, dynamic>
        ? BillBusinessProfile.fromJson(rawBp)
        : BillBusinessProfile.empty;

    return Bill(
      invoiceNo: json['invoiceNo']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerShopName: json['customerShopName']?.toString() ?? '',
      customerMobile: json['customerMobile']?.toString() ?? '',
      products: items,
      subtotal: (json['subtotal'] as num?)?.toDouble() ??
          (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Paid',
      businessProfile: bp,
      createdAt: json['createdAt']?.toString() ?? '',
      priorOutstanding:
          (json['priorOutstanding'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Human-readable date from ISO createdAt string.
  String get displayDate {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}
