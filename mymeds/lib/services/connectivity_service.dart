import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Enum for connection types
enum ConnectionType {
  wifi,
  mobile,
  none,
}

/// Service for monitoring network connectivity
/// 
/// Provides real-time detection of Wi-Fi, mobile, and offline states.
/// Useful for Data Saver Mode to determine when to defer sync operations.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  ConnectionType _currentConnectionType = ConnectionType.none;

  /// Stream of connectivity changes
  late Stream<ConnectionType> _connectionStream;

  ConnectionType get currentConnectionType => _currentConnectionType;

  Stream<ConnectionType> get connectionStream => _connectionStream;

  /// Initialize the connectivity service
  Future<void> init() async {
    // Get initial connection type
    final results = await _connectivity.checkConnectivity();
    _currentConnectionType = _mapResultToConnectionType(results);

    // Listen to connectivity changes
    _connectionStream = _connectivity.onConnectivityChanged.map((results) {
      _currentConnectionType = _mapResultToConnectionType(results);
      debugPrint('🌐 Connectivity changed: $_currentConnectionType');
      return _currentConnectionType;
    });
  }

  /// Map ConnectivityResult(s) to ConnectionType
  ConnectionType _mapResultToConnectionType(dynamic result) {
    // Handle both single ConnectivityResult and List<ConnectivityResult>
    List<ConnectivityResult> results;
    
    if (result is List) {
      results = List<ConnectivityResult>.from(result);
    } else if (result is ConnectivityResult) {
      results = [result];
    } else {
      return ConnectionType.none;
    }

    // Check for Wi-Fi first (highest priority)
    if (results.contains(ConnectivityResult.wifi)) {
      return ConnectionType.wifi;
    }
    
    // Then check for mobile data
    if (results.contains(ConnectivityResult.mobile)) {
      return ConnectionType.mobile;
    }
    
    // Default to offline
    return ConnectionType.none;
  }

  /// Check if currently on Wi-Fi
  bool get isWiFi => _currentConnectionType == ConnectionType.wifi;

  /// Check if currently on mobile data
  bool get isMobile => _currentConnectionType == ConnectionType.mobile;

  /// Check if offline
  bool get isOffline => _currentConnectionType == ConnectionType.none;

  /// Check if has any connection
  bool get isConnected => _currentConnectionType != ConnectionType.none;

  /// Dispose resources (called on app shutdown)
  void dispose() {
    debugPrint('🌐 ConnectivityService disposed');
  }
}
