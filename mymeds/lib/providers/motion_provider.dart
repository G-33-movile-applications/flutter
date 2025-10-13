import 'package:flutter/foundation.dart';
import '../services/motion_service.dart';

class MotionProvider with ChangeNotifier {
  final MotionService _motionService = MotionService();
  MotionState _motionState = MotionState.idle;
  MotionState? _manualState;

  bool _isDriving = false;
  bool _alertShown = false;
  
  MotionState get motionState => _manualState ?? _motionState; // 👈 override logic
  MotionState? get manualState => _manualState; // 👈 added getter
  
  bool get isDriving => _isDriving;
  bool get alertShown => _alertShown;

  void setIsDriving(bool value) {
    _isDriving = value;
    notifyListeners();
  }

  void setAlertShown(bool value) {
    _alertShown = value;
    notifyListeners();
  }

  /// Start listening to motion events
  void start() {
    _motionService.start();
    _motionService.motionStream.listen((state) {
      _motionState = state;

      // Update flags automatically if user starts/stops driving
      if (state == MotionState.driving && !_alertShown) {
        _alertShown = false; // ensure alert triggers later
      } else if (state != MotionState.driving) {
        _isDriving = false;
        _alertShown = false;
      }

      notifyListeners();
    });
  }

  void stop() {
    _motionService.stop();
  }

  void setManualState(MotionState? state) {
    _manualState = state;
    notifyListeners();
  }

}
