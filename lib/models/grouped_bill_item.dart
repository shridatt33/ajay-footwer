/// A display-only grouping of bill lines that share the same product.
///
/// The underlying data (individual size records) is NOT changed.
/// This class is only used for rendering bills, previews and PDFs.
class GroupedBillLine {
  const GroupedBillLine({
    required this.productId,
    required this.productName,
    required this.sizeLines,
    required this.totalQty,
    required this.totalAmount,
    required this.commonPrice, // null when sizes have different prices
  });

  final String productId;
  final String productName;

  /// Individual size entries: [(size, qty, lineTotal, unitPrice), ...]
  final List<SizeLine> sizeLines;

  final int totalQty;
  final double totalAmount;

  /// Non-null when every size in this group shares the same unit price.
  final double? commonPrice;
}

class SizeLine {
  const SizeLine({
    required this.size,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String size;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}
