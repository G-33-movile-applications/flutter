import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/motion_service.dart';

class MotionProvider with ChangeNotifier {
  final MotionService _motionService = MotionService();
  MotionState _motionState = MotionState.idle;
  MotionState? _manualState;

  bool _isDrivingConfirmed = false;
  bool _alertShown = false;
  bool _needsUserConfirmation = false;
  
  // Cooldown after user says "No"
  DateTime? _lastNoAt;
  
  // Timers for state management
  Timer? _drivingDebounceTimer;
  Timer? _notDrivingSettleTimer;
  
  // Configuration
  static const Duration _drivingDebounceDuration = Duration(seconds: 2);
  static const Duration _notDrivingSettleDuration = Duration(seconds: 15);
  static const Duration _confirmationCooldown = Duration(minutes: 5);
  
  MotionState get motionState => _manualState ?? _motionState;
  MotionState? get manualState => _manualState;
  MotionState get sensorState => _motionState; // Raw sensor reading
  
  bool get isDriving => _isDrivingConfirmed;
  bool get alertShown => _alertShown;
  bool get needsUserConfirmation => _needsUserConfirmation;
  
  // Get current accelerometer magnitude for debugging
  double get currentMagnitude => _motionService.lastMagnitude;

  void setIsDrivingConfirmed(bool value) {
    if (value) {
      // User confirmed driving
      _isDrivingConfirmed = true;
      _needsUserConfirmation = false;
      _alertShown = false;
      // Cancel any pending settle timer
      _notDrivingSettleTimer?.cancel();
    } else {
      // User said "No" - set cooldown
      _isDrivingConfirmed = false;
      _needsUserConfirmation = false;
      _alertShown = false;
      _lastNoAt = DateTime.now();
    }
    notifyListeners();
  }

  void markDialogShown() {
    _alertShown = true;
    notifyListeners();
  }

  void markDialogClosed() {
    _alertShown = false;
    notifyListeners();
  }

  /// Start listening to motion events
  void start() {
    _motionService.start();
    _motionService.motionStream.listen((state) {
      // Clear manual override when sensor changes significantly
      if (_manualState != null && state != _manualState) {
        _manualState = null;
      }

      _motionState = state;

      if (state == MotionState.driving) {
        // Cancel any not-driving settle timer
        _notDrivingSettleTimer?.cancel();
        
        // Start debounce timer for driving confirmation
        _drivingDebounceTimer?.cancel();
        _drivingDebounceTimer = Timer(_drivingDebounceDuration, () {
          // Only proceed if still driving after debounce
          if (_motionState != MotionState.driving) return;
          
          // Don't prompt if already confirmed or in cooldown
          if (_isDrivingConfirmed) return;
          
          // Check cooldown period
          if (_lastNoAt != null) {
            final timeSinceNo = DateTime.now().difference(_lastNoAt!);
            if (timeSinceNo < _confirmationCooldown) return;
          }
          
          // Trigger confirmation dialog
          _needsUserConfirmation = true;
          notifyListeners();
        });
      } else {
        // Not driving - cancel driving debounce
        _drivingDebounceTimer?.cancel();
        
        // If currently confirmed as driving, start settle timer
        if (_isDrivingConfirmed) {
          _notDrivingSettleTimer?.cancel();
          _notDrivingSettleTimer = Timer(_notDrivingSettleDuration, () {
            // Only exit driving mode if still not driving after settle period
            if (_motionState != MotionState.driving) {
              _isDrivingConfirmed = false;
              _needsUserConfirmation = false;
              notifyListeners();
            }
          });
        } else {
          // Not confirmed as driving, ensure no pending confirmation
          _needsUserConfirmation = false;
        }
      }

      notifyListeners();
    });
  }

  void stop() {
    _drivingDebounceTimer?.cancel();
    _notDrivingSettleTimer?.cancel();
    _motionService.stop();
  }

  void setManualState(MotionState? state) {
    _manualState = state;
    
    // If manually setting to driving, auto-confirm
    if (state == MotionState.driving) {
      _isDrivingConfirmed = true;
      _alertShown = false;
      _needsUserConfirmation = false;
      _notDrivingSettleTimer?.cancel();
    } else if (state != MotionState.driving && _manualState == MotionState.driving) {
      // Manually exiting driving mode
      _isDrivingConfirmed = false;
      _needsUserConfirmation = false;
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    _drivingDebounceTimer?.cancel();
    _notDrivingSettleTimer?.cancel();
    _motionService.dispose();
    super.dispose();
  }
}
