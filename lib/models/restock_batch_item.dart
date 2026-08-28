import 'product.dart';

/// In-memory representation of a single line in a bulk restock order.
/// Not persisted directly — converted to [RestockModel] records on submit.
class RestockBatchItem {
  final Product product;
  int quantity;
  double costPerUnit;

  RestockBatchItem({
    required this.product,
    required this.quantity,
    required this.costPerUnit,
  });

  double get subtotal => quantity * costPerUnit;

  RestockBatchItem copyWith({
    int? quantity,
    double? costPerUnit,
  }) {
    return RestockBatchItem(
      product: product,
      quantity: quantity ?? this.quantity,
      costPerUnit: costPerUnit ?? this.costPerUnit,
    );
  }
}
