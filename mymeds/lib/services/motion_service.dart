import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

enum MotionState { idle, walking, running, driving }

class MotionService {
  final _motionController = StreamController<MotionState>.broadcast();
  Stream<MotionState> get motionStream => _motionController.stream;

  StreamSubscription? _accelSub;
  StreamSubscription<Position>? _locationSub;
  MotionState? _lastState;
  Timer? _debounceTimer;
  List<double> _recentMagnitudes = [];
  List<double> _recentSpeeds = [];
  static const int _sampleSize = 10; // Number of samples to average
  static const int _speedSampleSize = 5; // GPS speed samples
  static const Duration _debounceDuration = Duration(seconds: 2);

  // Speed thresholds (in m/s)
  static const double _walkingSpeedThreshold = 2.0; // ~7.2 km/h
  static const double _runningSpeedThreshold = 3.5; // ~12.6 km/h
  static const double _drivingSpeedThreshold = 8.0; // ~28.8 km/h (more reliable for vehicle detection)

  // Current raw data for debugging
  double _lastMagnitude = 9.8;
  double _lastSpeed = 0.0;
  bool _isSpeedDetectionActive = false;

  double get lastMagnitude => _lastMagnitude;
  double get lastSpeed => _lastSpeed;
  bool get isSpeedDetectionActive => _isSpeedDetectionActive;

  void start() {
    // Start accelerometer-based detection (existing method)
    _startAccelerometerDetection();
    
    // Start GPS speed-based detection (new method for better accuracy)
    _startSpeedDetection();
  }

  void _startAccelerometerDetection() {
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
      final variance = _recentMagnitudes.map((m) => (m - avgMagnitude) * (m - avgMagnitude)).reduce((a, b) => a + b) / _recentMagnitudes.length;
      
      _evaluateMotionState(avgMagnitude, variance);
    });
  }

  Future<void> _startSpeedDetection() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled. Speed detection unavailable.');
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions denied. Speed detection unavailable.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied. Speed detection unavailable.');
        return;
      }

      _isSpeedDetectionActive = true;

      // Start listening to position updates for speed detection
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _locationSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          // GPS speed is in m/s, convert from nullable
          final speed = position.speed;
          _lastSpeed = speed;

          // Add to recent speeds for averaging
          _recentSpeeds.add(speed);
          if (_recentSpeeds.length > _speedSampleSize) {
            _recentSpeeds.removeAt(0);
          }

          // Evaluate motion state with speed data
          _evaluateMotionStateWithSpeed();
        },
        onError: (error) {
          debugPrint('Error in speed detection: $error');
          _isSpeedDetectionActive = false;
        },
      );

      debugPrint('Speed-based driving detection started successfully');
    } catch (e) {
      debugPrint('Failed to start speed detection: $e');
      _isSpeedDetectionActive = false;
    }
  }

  void _evaluateMotionState(double avgMagnitude, double variance) {
    MotionState newState;
    
    // Improved detection logic (existing accelerometer-based method)
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

    _emitStateIfChanged(newState);
  }

  void _evaluateMotionStateWithSpeed() {
    if (_recentSpeeds.isEmpty) return;

    // Calculate average speed
    final avgSpeed = _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;

    MotionState speedBasedState;

    // GPS speed-based detection (more accurate for driving)
    if (avgSpeed >= _drivingSpeedThreshold) {
      // Speed indicates vehicle movement
      speedBasedState = MotionState.driving;
    } else if (avgSpeed >= _runningSpeedThreshold) {
      speedBasedState = MotionState.running;
    } else if (avgSpeed >= _walkingSpeedThreshold) {
      speedBasedState = MotionState.walking;
    } else {
      speedBasedState = MotionState.idle;
    }

    debugPrint('Speed-based detection: ${avgSpeed.toStringAsFixed(2)} m/s → $speedBasedState');
    _emitStateIfChanged(speedBasedState);
  }

  void _emitStateIfChanged(MotionState newState) {
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
  }

  void stop() {
    _accelSub?.cancel();
    _locationSub?.cancel();
    _debounceTimer?.cancel();
    _motionController.close();
  }

  void dispose() {
    stop();
  }
}
