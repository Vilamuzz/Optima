import 'dart:async';
import 'package:flutter/material.dart';
import '../models/store_profile_model.dart';
import '../services/store_profile_service.dart';

class StoreProfileProvider extends ChangeNotifier {
  final StoreProfileService _service = StoreProfileService();
  StoreProfileModel _profile = const StoreProfileModel();
  bool _isLoading = false;
  StreamSubscription<StoreProfileModel>? _subscription;

  StoreProfileModel get profile => _profile;
  bool get isLoading => _isLoading;

  StoreProfileProvider() {
    _initStream();
  }

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _service.streamProfile().listen((updatedProfile) {
      _profile = updatedProfile;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('StoreProfileProvider stream error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateProfile(StoreProfileModel newProfile) async {
    _profile = newProfile;
    notifyListeners();
    await _service.saveProfile(newProfile);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
