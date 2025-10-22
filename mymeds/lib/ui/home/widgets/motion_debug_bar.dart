import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/motion_provider.dart';
import '../../../services/motion_service.dart';

/// Debug status bar for motion detection testing
/// Shows below the bottom navigation bar
class MotionDebugBar extends StatelessWidget {
  const MotionDebugBar({super.key});

  @override
  Widget build(BuildContext context) {
    final motionProvider = context.watch<MotionProvider>();
    final sensorState = motionProvider.sensorState;
    final manualState = motionProvider.manualState;
    final isDrivingConfirmed = motionProvider.isDriving;
    final magnitude = motionProvider.currentMagnitude;
    final speed = motionProvider.currentSpeed;
    final speedActive = motionProvider.isSpeedDetectionActive;

    final effectiveState = motionProvider.motionState;

    Color getStateColor(MotionState state) {
      switch (state) {
        case MotionState.idle:
          return Colors.grey;
        case MotionState.walking:
          return Colors.blue;
        case MotionState.running:
          return Colors.orange;
        case MotionState.driving:
          return Colors.red;
      }
    }

    String getStateEmoji(MotionState state) {
      switch (state) {
        case MotionState.idle:
          return '🪑';
        case MotionState.walking:
          return '🚶‍♂️';
        case MotionState.running:
          return '🏃‍♂️';
        case MotionState.driving:
          return '🚗';
      }
    }

    return GestureDetector(
      onTap: () => _showDebugDialog(context, motionProvider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: getStateColor(effectiveState).withOpacity(0.2),
          border: Border(
            top: BorderSide(
              color: getStateColor(effectiveState),
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${getStateEmoji(sensorState)} Sensor: ${sensorState.name.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Mag: ${magnitude.toStringAsFixed(2)} m/s²',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    speedActive 
                        ? '📍 GPS: ${(speed * 3.6).toStringAsFixed(1)} km/h'
                        : '📍 GPS: Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      color: speedActive ? Colors.blue[700] : Colors.grey,
                      fontWeight: speedActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  speedActive ? 'Speed: ${speed.toStringAsFixed(2)} m/s' : '',
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  manualState != null 
                      ? '${getStateEmoji(manualState)} Manual: ${manualState.name.toUpperCase()}'
                      : '📱 Manual: NONE',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDrivingConfirmed ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDrivingConfirmed ? '🚫 BLOCKED' : '✅ ACTIVE',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDebugDialog(BuildContext context, MotionProvider motionProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🛠️ Motion Debug Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Force Manual State:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...MotionState.values.map((state) {
              final isActive = motionProvider.manualState == state;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.blue : Colors.grey[300],
                      foregroundColor: isActive ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      motionProvider.setManualState(isActive ? null : state);
                      Navigator.pop(context);
                    },
                    child: Text(
                      isActive 
                          ? '✓ ${state.name.toUpperCase()} (Active)'
                          : state.name.toUpperCase(),
                    ),
                  ),
                ),
              );
            }).toList(),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  motionProvider.setManualState(null);
                  Navigator.pop(context);
                },
                child: const Text('Clear Manual Override'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
