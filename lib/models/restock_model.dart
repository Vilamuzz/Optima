import 'package:cloud_firestore/cloud_firestore.dart';

class RestockModel {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double costPerUnit;
  final double totalCost;
  final String? userId;
  final DateTime createdAt;
  /// Groups all items submitted in the same bulk restock session.
  final String? batchId;

  RestockModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPerUnit,
    required this.totalCost,
    this.userId,
    required this.createdAt,
    this.batchId,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'user_id': userId,
      'created_at': Timestamp.fromDate(createdAt),
      'batch_id': batchId,
    };
  }

  factory RestockModel.fromMap(String id, Map<String, dynamic> data) {
    return RestockModel(
      id: id,
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? '',
      quantity: data['quantity'] ?? 0,
      costPerUnit: (data['cost_per_unit'] ?? 0).toDouble(),
      totalCost: (data['total_cost'] ?? 0).toDouble(),
      userId: data['user_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      batchId: data['batch_id'],
    );
  }
}
