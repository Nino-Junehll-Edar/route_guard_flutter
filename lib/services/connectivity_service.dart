import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring internet connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  ConnectivityService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // Check initial connectivity status
    _isConnected = await _checkConnectivity();
    _connectivityController.add(_isConnected);

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      final isConnected = await _checkConnectivity();
      if (isConnected != _isConnected) {
        _isConnected = isConnected;
        _connectivityController.add(isConnected);
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.length == 1 && result.first == ConnectivityResult.none) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return true; // Assume connected if we can't determine
    }
  }

  Stream<bool> get connectivityStream => _connectivityController.stream;

  Future<void> dispose() async {
    await _connectivityController.close();
  }
}