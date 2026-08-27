class Product {
  final String id;
  final String name;
  final String? barcode;
  final double price;
  final int stockQty;
  final int lowStockThreshold;
  final String? supplierId;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.price,
    required this.stockQty,
    required this.lowStockThreshold,
    this.supplierId,
    required this.createdAt,
  });

  // Convert Firestore doc to Product
  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      barcode: data['barcode'],
      price: (data['price'] ?? 0).toDouble(),
      stockQty: data['stock_qty'] ?? 0,
      lowStockThreshold: data['low_stock_threshold'] ?? 0,
      supplierId: data['supplier_id'],
      createdAt: (data['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert Product to Firestore doc
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'price': price,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'supplier_id': supplierId,
      'created_at': createdAt,
    };
  }
}