class StoreProfileModel {
  final String name;
  final String address;
  final String phone;
  final String receiptFooter;

  const StoreProfileModel({
    this.name = 'TOKO SUMBER BERKAT',
    this.address = 'Jl. Surya No. 22, Surakarta, Jawa Tengah',
    this.phone = '0812-3456-7890',
    this.receiptFooter = 'Terima Kasih Atas Kunjungan Anda!',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'receiptFooter': receiptFooter,
    };
  }

  factory StoreProfileModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StoreProfileModel();
    return StoreProfileModel(
      name: map['name'] as String? ?? 'TOKO SUMBER BERKAT',
      address: map['address'] as String? ?? 'Jl. Surya No. 22, Surakarta, Jawa Tengah',
      phone: map['phone'] as String? ?? '0812-3456-7890',
      receiptFooter: map['receiptFooter'] as String? ?? 'Terima Kasih Atas Kunjungan Anda!',
    );
  }

  StoreProfileModel copyWith({
    String? name,
    String? address,
    String? phone,
    String? receiptFooter,
  }) {
    return StoreProfileModel(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }
}
