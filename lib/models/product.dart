class Product {
  final String id;
  final String name;
  final String? barcode;
  final String? category;
  final double price;
  final int stockQty;
  final int lowStockThreshold;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.category,
    required this.price,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.createdAt,
  });

  // Convert Firestore doc to Product
  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      barcode: data['barcode'],
      category: data['category'],
      price: (data['price'] ?? 0).toDouble(),
      stockQty: data['stock_qty'] ?? 0,
      lowStockThreshold: data['low_stock_threshold'] ?? 0,
      createdAt: (data['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert Product to Firestore doc
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'category': category,
      'price': price,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'created_at': createdAt,
    };
  }
}