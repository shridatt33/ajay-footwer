import '../models/bill.dart';
import '../models/billing_cart_item.dart';
import 'grouped_bill_item.dart';

/// Groups [BillingCartItem] lines by productId for display purposes.
/// The original list is NOT modified — this is display-only grouping.
List<GroupedBillLine> groupCartItems(List<BillingCartItem> items) {
  final Map<String, _Accumulator> acc = {};
  final List<String> order = [];

  for (final item in items) {
    final pid = item.product.productId;
    if (!acc.containsKey(pid)) {
      acc[pid] = _Accumulator(productName: item.product.productName);
      order.add(pid);
    }
    acc[pid]!.add(
      size: item.selectedSize,
      quantity: item.quantity,
      unitPrice: item.sellingPrice,
      lineTotal: item.lineTotal,
    );
  }

  return order
      .map((pid) => acc[pid]!.toGroup(pid))
      .toList(growable: false);
}

/// Groups [BillItem] lines (from history) by productId for display purposes.
List<GroupedBillLine> groupBillItems(List<BillItem> items) {
  final Map<String, _Accumulator> acc = {};
  final List<String> order = [];

  for (final item in items) {
    final pid = item.productId;
    if (!acc.containsKey(pid)) {
      acc[pid] = _Accumulator(productName: item.productName);
      order.add(pid);
    }
    acc[pid]!.add(
      size: item.size,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      lineTotal: item.lineTotal,
    );
  }

  return order
      .map((pid) => acc[pid]!.toGroup(pid))
      .toList(growable: false);
}

// ── internal accumulator ────────────────────────────────────────────────────

class _Accumulator {
  _Accumulator({required this.productName});

  final String productName;
  final List<SizeLine> sizeLines = [];
  int totalQty = 0;
  double totalAmount = 0;

  void add({
    required String size,
    required int quantity,
    required double unitPrice,
    required double lineTotal,
  }) {
    sizeLines.add(SizeLine(
      size: size,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
    ));
    totalQty += quantity;
    totalAmount += lineTotal;
  }

  GroupedBillLine toGroup(String productId) {
    // Common price only when every size has the same unit price.
    final prices = sizeLines.map((s) => s.unitPrice).toSet();
    final commonPrice = prices.length == 1 ? prices.first : null;

    return GroupedBillLine(
      productId: productId,
      productName: productName,
      sizeLines: List.unmodifiable(sizeLines),
      totalQty: totalQty,
      totalAmount: totalAmount,
      commonPrice: commonPrice,
    );
  }
}
