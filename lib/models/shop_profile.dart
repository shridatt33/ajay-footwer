class ShopProfile {
  final String shopName;
  final String ownerName;
  final String mobile;
  final String email;
  final String gstNumber;
  final String address;
  final String businessHours;

  const ShopProfile({
    required this.shopName,
    required this.ownerName,
    required this.mobile,
    required this.email,
    required this.gstNumber,
    required this.address,
    required this.businessHours,
  });

  /// Defaults shown on first-time setup before any saved profile exists.
  static const ShopProfile defaults = ShopProfile(
    shopName: 'Swamidatta Agencies',
    ownerName: 'Ajay Kumar',
    mobile: '+91 98765 43210',
    email: 'contact@swamidatta.com',
    gstNumber: '27AABCU9603R1ZM',
    address: 'Plot No. 42, Footwear Market, Station Road, Kolhapur, Maharashtra - 416001',
    businessHours: 'Mon - Sat: 9:00 AM - 8:30 PM',
  );

  factory ShopProfile.fromJson(Map<String, dynamic> json) {
    return ShopProfile(
      shopName: json['shopName']?.toString() ?? defaults.shopName,
      ownerName: json['ownerName']?.toString() ?? defaults.ownerName,
      mobile: json['mobileNumber']?.toString() ?? json['mobile']?.toString() ?? defaults.mobile,
      email: json['email']?.toString() ?? defaults.email,
      gstNumber: json['gstNumber']?.toString() ?? defaults.gstNumber,
      address: json['shopAddress']?.toString() ?? json['address']?.toString() ?? defaults.address,
      businessHours: json['businessHours']?.toString() ?? defaults.businessHours,
    );
  }

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'ownerName': ownerName,
        'mobileNumber': mobile,
        'email': email,
        'gstNumber': gstNumber,
        'shopAddress': address,
        'businessHours': businessHours,
      };

  ShopProfile copyWith({
    String? shopName,
    String? ownerName,
    String? mobile,
    String? email,
    String? gstNumber,
    String? address,
    String? businessHours,
  }) {
    return ShopProfile(
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      businessHours: businessHours ?? this.businessHours,
    );
  }
}
