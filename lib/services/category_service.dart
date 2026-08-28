import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Stream<List<CategoryModel>> getCategories() {
    return _db
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<CategoryModel> addCategory(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Category name cannot be empty');
    }

    final String id = _uuid.v4();
    final category = CategoryModel(
      id: id,
      name: trimmedName,
      createdAt: DateTime.now(),
    );

    await _db.collection('categories').doc(id).set(category.toMap());
    return category;
  }

  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }
}
