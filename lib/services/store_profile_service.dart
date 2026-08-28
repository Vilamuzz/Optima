import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/store_profile.dart';

class StoreProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DocumentReference get _docRef => _db.collection('settings').doc('store_profile');

  /// Fetches current store profile from Firestore or returns default.
  Future<StoreProfileModel> getProfile() async {
    try {
      final snap = await _docRef.get();
      if (snap.exists && snap.data() != null) {
        return StoreProfileModel.fromMap(snap.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error fetching store profile: $e');
    }
    return const StoreProfileModel();
  }

  /// Updates or creates store profile in Firestore.
  Future<void> saveProfile(StoreProfileModel profile) async {
    try {
      await _docRef.set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving store profile: $e');
      rethrow;
    }
  }

  /// Real-time stream of store profile.
  Stream<StoreProfileModel> streamProfile() {
    return _docRef.snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return StoreProfileModel.fromMap(snap.data() as Map<String, dynamic>);
      }
      return const StoreProfileModel();
    });
  }
}
