import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

enum MotionState { idle, walking, running, driving }

class MotionService {
  final _motionController = StreamController<MotionState>.broadcast();
  Stream<MotionState> get motionStream => _motionController.stream;

  StreamSubscription? _accelSub;

  void start() {
    _accelSub = accelerometerEvents.listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      MotionState newState;
      if (magnitude < 10.2 && magnitude > 9.4) {
        newState = MotionState.idle;
      } else if (magnitude < 15) {
        newState = MotionState.walking;
      } else if (magnitude < 25) {
        newState = MotionState.running;
      } else {
        newState = MotionState.driving;
      }

      _motionController.add(newState);
    });
  }

  void stop() {
    _accelSub?.cancel();
    _motionController.close();
  }
}
