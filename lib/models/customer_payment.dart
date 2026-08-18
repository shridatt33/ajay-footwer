/// Represents a payment received from a customer, stored in MongoDB.
class CustomerPayment {
  final String id;
  final String customerId;
  final String customerName;
  final String customerShopName;
  final double amount;
  final String paymentDate; // ISO date string
  final String paymentMode; // Cash, UPI, Bank Transfer, Cheque, Other
  final String reference;
  final String note;
  /// Customer's outstanding balance BEFORE this payment.
  final double previousOutstanding;
  /// Customer's outstanding balance AFTER this payment.
  final double balanceAfter;
  final String createdAt;

  const CustomerPayment({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerShopName,
    required this.amount,
    required this.paymentDate,
    required this.paymentMode,
    required this.reference,
    required this.note,
    required this.previousOutstanding,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory CustomerPayment.fromJson(Map<String, dynamic> json) {
    return CustomerPayment(
      id: json['paymentId']?.toString() ??
          json['_id']?.toString() ??
          json['id']?.toString() ??
          '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerShopName: json['customerShopName']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['paymentDate']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? 'Cash',
      reference: json['reference']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      previousOutstanding:
          (json['previousOutstanding'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'customerName': customerName,
        'customerShopName': customerShopName,
        'amount': amount,
        'paymentDate': paymentDate,
        'paymentMode': paymentMode,
        'reference': reference,
        'note': note,
        'previousOutstanding': previousOutstanding,
        'balanceAfter': balanceAfter,
      };

  /// Human-readable date from ISO paymentDate / createdAt string.
  String get displayDate {
    final raw = paymentDate.isNotEmpty ? paymentDate : createdAt;
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  /// Human-readable time from ISO paymentDate / createdAt string.
  String get displayTime {
    final raw = paymentDate.isNotEmpty ? paymentDate : createdAt;
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour;
      final m = dt.minute;
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '';
    }
  }
}
