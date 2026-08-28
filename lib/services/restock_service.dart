import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/restock.dart';

/// Describes a single product line for a bulk restock submission.
class RestockLineInput {
  final String productId;
  final int quantity;
  final double costPerUnit;

  const RestockLineInput({
    required this.productId,
    required this.quantity,
    required this.costPerUnit,
  });
}

class RestockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Processes restock atomically:
  /// 1. Increments product's stock_qty in Firestore product doc.
  /// 2. Records a entry in restocks collection.
  Future<RestockModel> processRestock({
    required String productId,
    required int quantity,
    required double costPerUnit,
    String? userId,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than 0');
    }
    if (costPerUnit < 0) {
      throw Exception('Cost per unit cannot be negative');
    }

    final double totalCost = quantity * costPerUnit;
    final String restockId = _uuid.v4();
    final DateTime now = DateTime.now();

    final productRef = _db.collection('products').doc(productId);
    final restockRef = _db.collection('restocks').doc(restockId);

    late String productName;

    await _db.runTransaction((transaction) async {
      // Step 1: Read product doc inside transaction
      final productDoc = await transaction.get(productRef);
      if (!productDoc.exists) {
        throw Exception('Selected product does not exist.');
      }

      final data = productDoc.data()!;
      productName = data['name'] ?? 'Unknown Product';
      final int currentStock = data['stock_qty'] ?? 0;

      // Step 2: Increment stock_qty
      final int newStock = currentStock + quantity;
      transaction.update(productRef, {
        'stock_qty': newStock,
      });

      // Step 3: Record restock entry
      final restockModel = RestockModel(
        id: restockId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        costPerUnit: costPerUnit,
        totalCost: totalCost,
        userId: userId,
        createdAt: now,
      );

      transaction.set(restockRef, restockModel.toMap());
    });

    return RestockModel(
      id: restockId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      costPerUnit: costPerUnit,
      totalCost: totalCost,
      userId: userId,
      createdAt: now,
    );
  }

  /// Processes a bulk restock order atomically using a Firestore batch write.
  ///
  /// All line items share the same [batchId] so history can group them.
  /// For each line it:
  ///  1. Reads current product stock (via a Firestore transaction).
  ///  2. Increments stock_qty for every product.
  ///  3. Writes one RestockModel document per line, all sharing the batchId.
  Future<List<RestockModel>> processBulkRestock({
    required List<RestockLineInput> lines,
    String? userId,
  }) async {
    if (lines.isEmpty) throw Exception('No items in restock order.');

    final String batchId = _uuid.v4();
    final DateTime now = DateTime.now();
    final List<RestockModel> results = [];

    // Use a Firestore transaction so stock reads + writes are atomic.
    await _db.runTransaction((transaction) async {
      // ---- READS FIRST ----
      final List<Map<String, dynamic>> lineData = [];
      for (final line in lines) {
        if (line.quantity <= 0) {
          throw Exception('Quantity must be > 0 for all items.');
        }
        final productRef = _db.collection('products').doc(line.productId);
        final productDoc = await transaction.get(productRef);
        if (!productDoc.exists) {
          throw Exception('Product ${line.productId} no longer exists.');
        }
        final data = productDoc.data()!;
        lineData.add({
          'ref': productRef,
          'name': data['name'] ?? 'Unknown',
          'currentStock': data['stock_qty'] ?? 0,
          'line': line,
        });
      }

      // ---- WRITES ----
      for (final entry in lineData) {
        final productRef = entry['ref'] as DocumentReference;
        final line = entry['line'] as RestockLineInput;
        final int newStock = (entry['currentStock'] as int) + line.quantity;

        transaction.update(productRef, {
          'stock_qty': newStock,
        });

        final String restockId = _uuid.v4();
        final double totalCost = line.quantity * line.costPerUnit;
        final restockModel = RestockModel(
          id: restockId,
          productId: line.productId,
          productName: entry['name'] as String,
          quantity: line.quantity,
          costPerUnit: line.costPerUnit,
          totalCost: totalCost,
          userId: userId,
          createdAt: now,
          batchId: batchId,
        );

        final restockRef = _db.collection('restocks').doc(restockId);
        transaction.set(restockRef, restockModel.toMap());
        results.add(restockModel);
      }
    });

    return results;
  }

  /// Returns stream of all restock log entries.
  Stream<List<RestockModel>> getRestocks() {
    return _db
        .collection('restocks')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RestockModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Returns stream of recent restock log entries up to [limit].
  Stream<List<RestockModel>> getRestocksStream({int limit = 100}) {
    return _db
        .collection('restocks')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RestockModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Returns stream of restock log entries for the specified month.
  Stream<List<RestockModel>> getRestocksForMonthStream(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    return _db
        .collection('restocks')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RestockModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}

