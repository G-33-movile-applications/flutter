import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/motion_provider.dart';
import '../services/motion_service.dart';

class MotionAlert extends StatelessWidget {
  const MotionAlert({super.key});

  @override
  Widget build(BuildContext context) {
    final motion = context.watch<MotionProvider>().motionState;

    String? message;
    if (motion == MotionState.walking || motion == MotionState.running) {
      message = "You’re moving";
    } else if (motion == MotionState.driving) {
      message = "Driving detected — some functions might be limited";
    }

    if (message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.amber.shade700,
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
