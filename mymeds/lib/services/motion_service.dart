import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

enum MotionState { idle, walking, running, driving }

class MotionService {
  final _motionController = StreamController<MotionState>.broadcast();
  Stream<MotionState> get motionStream => _motionController.stream;

  StreamSubscription? _accelSub;
  MotionState? _lastState;
  Timer? _debounceTimer;
  List<double> _recentMagnitudes = [];
  static const int _sampleSize = 10; // Number of samples to average
  static const Duration _debounceDuration = Duration(seconds: 2);

  // Current raw accelerometer data for debugging
  double _lastMagnitude = 9.8;
  double get lastMagnitude => _lastMagnitude;

  void start() {
    _accelSub = accelerometerEvents.listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _lastMagnitude = magnitude;

      // Add to recent samples
      _recentMagnitudes.add(magnitude);
      if (_recentMagnitudes.length > _sampleSize) {
        _recentMagnitudes.removeAt(0);
      }

      // Calculate average magnitude for more stable detection
      final avgMagnitude = _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;

      // Calculate variance to detect consistency
      final variance = _recentMagnitudes.map((m) => pow(m - avgMagnitude, 2)).reduce((a, b) => a + b) / _recentMagnitudes.length;

      MotionState newState;
      
      // Improved detection logic
      if (avgMagnitude >= 9.4 && avgMagnitude <= 10.5 && variance < 0.5) {
        // Low variance + near gravity = idle/stationary
        newState = MotionState.idle;
      } else if (avgMagnitude > 10.5 && avgMagnitude <= 15 && variance < 3) {
        // Moderate movement with some variance = walking
        newState = MotionState.walking;
      } else if (avgMagnitude > 15 && avgMagnitude <= 25) {
        // Higher movement = running
        newState = MotionState.running;
      } else if (avgMagnitude > 25 || (avgMagnitude > 15 && variance > 10)) {
        // Very high acceleration or high variance = likely in vehicle
        newState = MotionState.driving;
      } else {
        newState = MotionState.idle;
      }

      // Debounce: only emit if state persists for debounce duration
      if (newState != _lastState) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(_debounceDuration, () {
          if (!_motionController.isClosed) {
            _motionController.add(newState);
          }
        });
        _lastState = newState;
      }
    });
  }

  void stop() {
    _accelSub?.cancel();
    _debounceTimer?.cancel();
    _motionController.close();
  }

  void dispose() {
    stop();
  }
}
