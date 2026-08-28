import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Executes atomic checkout transaction in Firestore.
  /// 1. Reads current stock for all items in cart.
  /// 2. Validates stock availability.
  /// 3. Updates stock quantities for all items.
  /// 4. Creates a transaction record in Firestore.
  Future<TransactionModel> processCheckout({
    required List<CartItem> cartItems,
    required double amountPaid,
    String? cashierId,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Cannot checkout an empty cart.');
    }

    final String transactionId = _uuid.v4();
    final String timestampStr =
        DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final String transactionNumber = 'TRX-$timestampStr';

    final transactionRef = _db.collection('transactions').doc(transactionId);
    final DateTime now = DateTime.now();

    List<TransactionItem> finalTrxItems = [];
    double finalTotalAmount = 0;
    double finalChange = 0;

    await _db.runTransaction((transaction) async {
      // Step 1: Execute all reads first and snapshot price at sale
      final List<Map<String, dynamic>> productUpdates = [];
      final List<TransactionItem> snapshotItems = [];
      double calculatedTotal = 0;

      for (final cartItem in cartItems) {
        final productRef = _db.collection('products').doc(cartItem.product.id);
        final productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw Exception(
              'Product "${cartItem.product.name}" no longer exists.');
        }

        final data = productDoc.data()!;
        final int currentStock = data['stock_qty'] ?? 0;

        if (currentStock < cartItem.quantity) {
          throw Exception(
            'Insufficient stock for "${cartItem.product.name}". Available: $currentStock, Requested: ${cartItem.quantity}',
          );
        }

        // Snapshot price at time of sale from live Firestore doc (or cart fallback)
        final double priceAtSale = (data['price'] ?? cartItem.product.price).toDouble();
        final double itemSubtotal = priceAtSale * cartItem.quantity;
        calculatedTotal += itemSubtotal;

        snapshotItems.add(
          TransactionItem(
            productId: cartItem.product.id,
            productName: data['name'] ?? cartItem.product.name,
            priceAtSale: priceAtSale,
            quantity: cartItem.quantity,
            subtotal: itemSubtotal,
          ),
        );

        productUpdates.add({
          'ref': productRef,
          'newStock': currentStock - cartItem.quantity,
        });
      }

      final double calculatedChange =
          amountPaid >= calculatedTotal ? amountPaid - calculatedTotal : 0;

      // Step 2: Execute all stock updates
      for (final update in productUpdates) {
        final DocumentReference ref = update['ref'] as DocumentReference;
        final int newStock = update['newStock'] as int;
        transaction.update(ref, {'stock_qty': newStock});
      }

      // Step 3: Write new transaction record with price_at_sale snapshots
      final Map<String, dynamic> transactionData = {
        'transaction_number': transactionNumber,
        'items': snapshotItems.map((item) => item.toMap()).toList(),
        'total_amount': calculatedTotal,
        'amount_paid': amountPaid,
        'change': calculatedChange,
        'cashier_id': cashierId,
        'created_at': Timestamp.fromDate(now),
      };

      transaction.set(transactionRef, transactionData);

      finalTrxItems = snapshotItems;
      finalTotalAmount = calculatedTotal;
      finalChange = calculatedChange;
    });

    return TransactionModel(
      id: transactionId,
      transactionNumber: transactionNumber,
      items: finalTrxItems,
      totalAmount: finalTotalAmount,
      amountPaid: amountPaid,
      change: finalChange,
      cashierId: cashierId,
      createdAt: now,
    );
  }

  /// Stream to fetch all transaction history ordered by created_at descending
  Stream<List<TransactionModel>> getTransactions() {
    return _db
        .collection('transactions')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Returns recent transactions limited by count to prevent unbounded reads.
  Stream<List<TransactionModel>> getRecentTransactionsStream({int limit = 50}) {
    return _db
        .collection('transactions')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Returns transactions created from the specified start date onwards.
  Stream<List<TransactionModel>> getTransactionsFromDateStream(DateTime startDate) {
    return _db
        .collection('transactions')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Returns a stream of transactions created on the specified date.
  Stream<List<TransactionModel>> getTransactionsForDateStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    return _db
        .collection('transactions')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}

