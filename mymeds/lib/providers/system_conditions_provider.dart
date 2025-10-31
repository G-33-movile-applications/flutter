import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';

class SystemConditionsProvider with ChangeNotifier {
  final Battery _battery = Battery();
  bool _isLowPowerMode = false;
  int _batteryLevel = 100;
  ThemeMode _themeMode = ThemeMode.system;
  static const lowBatteryThreshold = 20;

  bool get isLowPowerMode => _isLowPowerMode;
  int get batteryLevel => _batteryLevel;
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  SystemConditionsProvider() {
    _initSystemConditions();
  }

  Future<void> _initSystemConditions() async {
    // Initial battery level
    _batteryLevel = await _battery.batteryLevel;
    
    // Setup battery state listener
    _battery.onBatteryStateChanged.listen((BatteryState state) async {
      _batteryLevel = await _battery.batteryLevel;
      _checkAndUpdatePowerMode();
      notifyListeners();
    });

    // Check initial power mode
    _checkAndUpdatePowerMode();
    
    // Get initial system theme mode and set up listener
    final window = WidgetsBinding.instance.platformDispatcher;
    window.onPlatformBrightnessChanged = () {
      // Only notify if we're in system mode
      if (_themeMode == ThemeMode.system) {
        notifyListeners();
      }
    };
  }

  void _checkAndUpdatePowerMode() {
    final shouldBeLowPower = _batteryLevel <= lowBatteryThreshold;
    if (shouldBeLowPower != _isLowPowerMode) {
      _isLowPowerMode = shouldBeLowPower;
      notifyListeners();
    }
  }

  void toggleThemeMode() {
    switch (_themeMode) {
      case ThemeMode.system:
        _themeMode = ThemeMode.light;
        break;
      case ThemeMode.light:
        _themeMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        _themeMode = ThemeMode.system;
        break;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}