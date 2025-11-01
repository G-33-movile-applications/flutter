import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../providers/system_conditions_provider.dart';

class LowBatteryToast extends StatefulWidget {
  final Widget child;

  const LowBatteryToast({
    super.key,
    required this.child,
  });

  @override
  State<LowBatteryToast> createState() => _LowBatteryToastState();
}

class _LowBatteryToastState extends State<LowBatteryToast> {
  bool _hasShownToast = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SystemConditionsProvider>(
      builder: (context, systemConditions, child) {
        // Show toast only when entering low power mode and hasn't shown yet
        if (systemConditions.isLowPowerMode && !_hasShownToast) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Fluttertoast.showToast(
              msg: "Modo ahorro activado automáticamente (batería baja)",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.TOP,
              backgroundColor: Colors.orange.withOpacity(0.9),
              textColor: Colors.white,
              fontSize: 16.0,
            );
            setState(() => _hasShownToast = true);
          });
        } else if (!systemConditions.isLowPowerMode) {
          // Reset flag when exiting low power mode
          _hasShownToast = false;
        }

        return widget.child;
      },
    );
  }
}