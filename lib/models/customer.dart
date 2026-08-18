class CustomerPurchase {
  final String invoiceNumber;
  final String date;
  final double amount;
  final String status; // 'Paid' or 'Pending'
  final String itemsSummary;

  const CustomerPurchase({
    required this.invoiceNumber,
    required this.date,
    required this.amount,
    required this.status,
    required this.itemsSummary,
  });

  factory CustomerPurchase.fromJson(Map<String, dynamic> json) {
    return CustomerPurchase(
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Paid',
      itemsSummary: json['itemsSummary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'date': date,
        'amount': amount,
        'status': status,
        'itemsSummary': itemsSummary,
      };
}

class Customer {
  final String id;
  final String name;
  final String shopName;
  final String mobile;
  final String email;
  final String address;
  final String gstNumber;
  final double outstandingBalance;
  final int totalBills;
  final List<CustomerPurchase> purchaseHistory;

  const Customer({
    required this.id,
    required this.name,
    required this.shopName,
    required this.mobile,
    required this.email,
    required this.address,
    required this.gstNumber,
    required this.outstandingBalance,
    required this.totalBills,
    required this.purchaseHistory,
  });

  /// Parse from Flask API response document.
  /// Backend uses "customerId" and "customerName" field names.
  factory Customer.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['purchaseHistory'];
    final history = rawHistory is List
        ? rawHistory
            .map((e) => CustomerPurchase.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : const <CustomerPurchase>[];

    return Customer(
      id: json['customerId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['customerName']?.toString() ?? json['name']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      gstNumber: json['gstNumber']?.toString() ?? '',
      outstandingBalance:
          (json['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
      totalBills: (json['totalBills'] as num?)?.toInt() ?? 0,
      purchaseHistory: history,
    );
  }

  /// Serialise to the shape the Flask POST/PUT endpoints expect.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'customerName': name,
      'shopName': shopName,
      'mobile': mobile,
      'email': email,
      'address': address,
      'gstNumber': gstNumber,
      'outstandingBalance': outstandingBalance,
      'totalBills': totalBills,
    };
    // Only include customerId when it is non-empty (edit flow).
    // For new customers, omit it so the backend generates it.
    if (id.isNotEmpty) {
      map['customerId'] = id;
    }
    return map;
  }

  Customer copyWith({
    String? id,
    String? name,
    String? shopName,
    String? mobile,
    String? email,
    String? address,
    String? gstNumber,
    double? outstandingBalance,
    int? totalBills,
    List<CustomerPurchase>? purchaseHistory,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      shopName: shopName ?? this.shopName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      totalBills: totalBills ?? this.totalBills,
      purchaseHistory: purchaseHistory ?? this.purchaseHistory,
    );
  }
}
