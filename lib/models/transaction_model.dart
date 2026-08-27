import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionItem {
  final String productId;
  final String productName;
  final double priceAtSale;
  final int quantity;
  final double subtotal;

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.priceAtSale,
    required this.quantity,
    required this.subtotal,
  });

  double get unitPrice => priceAtSale;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price_at_sale': priceAtSale,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> data) {
    return TransactionItem(
      productId: data['product_id'] ?? '',
      productName: data['product_name'] ?? '',
      priceAtSale: (data['price_at_sale'] ?? data['unit_price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 0,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
    );
  }
}

class TransactionModel {
  final String id;
  final String transactionNumber;
  final List<TransactionItem> items;
  final double totalAmount;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final String? cashierId;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.transactionNumber,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    this.cashierId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'transaction_number': transactionNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'amount_paid': amountPaid,
      'change': change,
      'cashier_id': cashierId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      transactionNumber: data['transaction_number'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (data['total_amount'] ?? 0).toDouble(),
      paymentMethod: data['payment_method'] ?? 'cash',
      amountPaid: (data['amount_paid'] ?? 0).toDouble(),
      change: (data['change'] ?? 0).toDouble(),
      cashierId: data['cashier_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
