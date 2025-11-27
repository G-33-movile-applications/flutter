import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_event.dart';

/// Service for managing smart notification scheduling based on user behavior
/// 
/// This service learns when users are most likely to interact with notifications
/// and optimizes scheduling to improve engagement while reducing interruptions.
/// 
/// Key features:
/// - Local learning: All data and calculations stay on-device
/// - Privacy-first: No data sharing without explicit user consent
/// - Adaptive: Learns from user patterns over time
/// - Respectful: Honors quiet hours and user preferences
class SmartNotificationService {
  static const String _boxName = 'notification_events';
  static const int _minEventsForLearning = 20;
  static const int _minDaysForLearning = 7;
  static const double _laplaceSmoothing = 1.0; // Prevents 0/1 extremes
  
  // Default quiet hours (22:00 - 7:00)
  static const int _defaultQuietStartHour = 22;
  static const int _defaultQuietEndHour = 7;
  
  // Time slot configuration (2-hour blocks)
  static const int _slotDurationHours = 2;
  
  Box<NotificationEvent>? _eventsBox;
  bool _initialized = false;
  
  // User preferences
  bool _smartNotificationsEnabled = true;
  int _quietStartHour = _defaultQuietStartHour;
  int _quietEndHour = _defaultQuietEndHour;
  
  // Cached analytics
  Map<int, double>? _cachedProbabilities;
  DateTime? _lastCalculationTime;
  static const Duration _cacheValidityDuration = Duration(hours: 6);

  /// Initialize the service and set up Hive storage
  Future<void> initialize() async {
    if (_initialized) return;
    
    debugPrint('🔔 [SmartNotificationService] Initializing...');
    
    try {
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(NotificationEventAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(NotificationResultAdapter());
      }
      
      // Open the events box
      _eventsBox = await Hive.openBox<NotificationEvent>(_boxName);
      _initialized = true;
      
      debugPrint('✅ [SmartNotificationService] Initialized with ${_eventsBox?.length ?? 0} events');
    } catch (e) {
      debugPrint('❌ [SmartNotificationService] Initialization error: $e');
      rethrow;
    }
  }

  /// Record a notification event (sent, opened, ignored, dismissed)
  Future<void> recordEvent({
    required String type,
    required NotificationResult result,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized();
    
    final event = NotificationEvent.create(
      type: type,
      result: result,
      timestamp: timestamp,
    );
    
    await _eventsBox!.add(event);
    
    // Invalidate cache when new data arrives
    _cachedProbabilities = null;
    
    debugPrint('📝 [SmartNotificationService] Recorded: $event');
  }

  /// Check if a notification should be sent now based on smart logic
  /// 
  /// Returns:
  /// - true: Send the notification now
  /// - false: Postpone the notification (with suggested time)
  Future<bool> shouldSendNotificationNow({
    required String type,
    bool isUrgent = false,
    DateTime? proposedTime,
  }) async {
    await _ensureInitialized();
    
    final checkTime = proposedTime ?? DateTime.now();
    
    // Urgent notifications bypass smart logic
    if (isUrgent) {
      debugPrint('🚨 [SmartNotificationService] Urgent notification - sending immediately');
      return true;
    }
    
    // Check if smart notifications are disabled
    if (!_smartNotificationsEnabled) {
      debugPrint('⚙️ [SmartNotificationService] Smart notifications disabled - using default rules');
      return !_isInQuietHours(checkTime);
    }
    
    // Check quiet hours first
    if (_isInQuietHours(checkTime)) {
      debugPrint('🌙 [SmartNotificationService] In quiet hours - should postpone');
      return false;
    }
    
    // Check if we have enough data for smart decisions
    if (!_hasEnoughDataForLearning()) {
      debugPrint('📊 [SmartNotificationService] Insufficient data - using default rules');
      return true; // Send if not in quiet hours
    }
    
    // Calculate probability for current time slot
    final currentSlot = _getTimeSlot(checkTime.hour);
    final probabilities = await _calculateProbabilities();
    final currentP = probabilities[currentSlot] ?? 0.5;
    
    // Find the best slot
    final bestSlot = _findBestSlot(probabilities);
    final bestP = probabilities[bestSlot] ?? 0.5;
    
    // Decision threshold: send if current P is within 80% of best P
    final threshold = bestP * 0.8;
    final shouldSend = currentP >= threshold;
    
    debugPrint('🤔 [SmartNotificationService] Decision for slot $currentSlot:');
    debugPrint('   Current P(t): ${(currentP * 100).toStringAsFixed(1)}%');
    debugPrint('   Best slot: $bestSlot with P(t): ${(bestP * 100).toStringAsFixed(1)}%');
    debugPrint('   Threshold: ${(threshold * 100).toStringAsFixed(1)}%');
    debugPrint('   Decision: ${shouldSend ? "SEND NOW" : "POSTPONE"}');
    
    return shouldSend;
  }

  /// Get the optimal time to send a postponed notification
  Future<DateTime> getOptimalSendTime({
    DateTime? afterTime,
    String? type,
  }) async {
    await _ensureInitialized();
    
    final referenceTime = afterTime ?? DateTime.now();
    
    // If not enough data, suggest next morning (8:00)
    if (!_hasEnoughDataForLearning()) {
      return _getNextMorning(referenceTime);
    }
    
    final probabilities = await _calculateProbabilities();
    final bestSlot = _findBestSlot(probabilities);
    
    // Calculate next occurrence of best slot
    final bestSlotHour = bestSlot;
    var nextOccurrence = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
      bestSlotHour,
      0,
    );
    
    // If the slot already passed today, move to tomorrow
    if (nextOccurrence.isBefore(referenceTime)) {
      nextOccurrence = nextOccurrence.add(const Duration(days: 1));
    }
    
    // Avoid quiet hours
    if (_isInQuietHours(nextOccurrence)) {
      nextOccurrence = _getNextMorning(nextOccurrence);
    }
    
    debugPrint('⏰ [SmartNotificationService] Optimal send time: $nextOccurrence (slot $bestSlot)');
    return nextOccurrence;
  }

  /// Calculate P(t) for each time slot
  /// 
  /// P(t) = (opens_in_slot + α) / (total_in_slot + 2α)
  /// where α is Laplace smoothing factor
  Future<Map<int, double>> _calculateProbabilities() async {
    // Return cached probabilities if still valid
    if (_cachedProbabilities != null && _lastCalculationTime != null) {
      final age = DateTime.now().difference(_lastCalculationTime!);
      if (age < _cacheValidityDuration) {
        return _cachedProbabilities!;
      }
    }
    
    // Run calculation in isolate to avoid blocking UI
    final events = _eventsBox!.values.toList();
    final probabilities = await _calculateProbabilitiesInIsolate(events);
    
    _cachedProbabilities = probabilities;
    _lastCalculationTime = DateTime.now();
    
    return probabilities;
  }

  /// Calculate probabilities in an isolate (background thread)
  Future<Map<int, double>> _calculateProbabilitiesInIsolate(
    List<NotificationEvent> events,
  ) async {
    // For small datasets, calculate directly
    if (events.length < 100) {
      return _computeProbabilities(events);
    }
    
    // For large datasets, use isolate
    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _probabilityCalculationIsolate,
      _IsolateParams(
        events: events,
        sendPort: receivePort.sendPort,
        smoothing: _laplaceSmoothing,
      ),
    );
    
    final result = await receivePort.first as Map<int, double>;
    return result;
  }

  /// Isolate entry point for probability calculation
  static void _probabilityCalculationIsolate(_IsolateParams params) {
    final result = _computeProbabilities(params.events, params.smoothing);
    params.sendPort.send(result);
  }

  /// Core probability calculation logic
  static Map<int, double> _computeProbabilities(
    List<NotificationEvent> events, [
    double smoothing = _laplaceSmoothing,
  ]) {
    // Count opens and total notifications per slot
    final Map<int, int> opensPerSlot = {};
    final Map<int, int> totalPerSlot = {};
    
    for (final event in events) {
      final slot = event.timeSlot;
      
      totalPerSlot[slot] = (totalPerSlot[slot] ?? 0) + 1;
      
      if (event.wasOpened) {
        opensPerSlot[slot] = (opensPerSlot[slot] ?? 0) + 1;
      }
    }
    
    // Calculate P(t) with Laplace smoothing for each slot
    final Map<int, double> probabilities = {};
    
    for (int slot = 0; slot < 24; slot += _slotDurationHours) {
      final opens = (opensPerSlot[slot] ?? 0).toDouble();
      final total = (totalPerSlot[slot] ?? 0).toDouble();
      
      // P(t) = (opens + α) / (total + 2α)
      final probability = (opens + smoothing) / (total + 2 * smoothing);
      probabilities[slot] = probability;
    }
    
    return probabilities;
  }

  /// Find the time slot with highest P(t)
  int _findBestSlot(Map<int, double> probabilities) {
    int bestSlot = 8; // Default to 8:00 AM
    double bestP = 0.0;
    
    for (final entry in probabilities.entries) {
      // Skip quiet hours
      if (_isSlotInQuietHours(entry.key)) continue;
      
      if (entry.value > bestP) {
        bestP = entry.value;
        bestSlot = entry.key;
      }
    }
    
    return bestSlot;
  }

  /// Check if we have enough data for learning
  bool _hasEnoughDataForLearning() {
    if (_eventsBox == null || _eventsBox!.isEmpty) return false;
    
    final events = _eventsBox!.values;
    
    // Check minimum event count
    if (events.length < _minEventsForLearning) return false;
    
    // Check minimum time range (days)
    final timestamps = events.map((e) => e.timestamp).toList();
    timestamps.sort();
    
    final oldestEvent = timestamps.first;
    final newestEvent = timestamps.last;
    final daySpan = newestEvent.difference(oldestEvent).inDays;
    
    return daySpan >= _minDaysForLearning;
  }

  /// Check if a time is in quiet hours
  bool _isInQuietHours(DateTime time) {
    final hour = time.hour;
    
    if (_quietStartHour < _quietEndHour) {
      // Normal case: e.g., 22:00 - 23:59 (same day)
      return false; // No quiet hours in this range
    } else {
      // Wraps midnight: e.g., 22:00 - 7:00
      return hour >= _quietStartHour || hour < _quietEndHour;
    }
  }

  /// Check if a slot overlaps with quiet hours
  bool _isSlotInQuietHours(int slotStartHour) {
    final slotEndHour = slotStartHour + _slotDurationHours;
    
    // Check if any hour in the slot is in quiet hours
    for (int h = slotStartHour; h < slotEndHour; h++) {
      if (_isInQuietHours(DateTime(2000, 1, 1, h))) {
        return true;
      }
    }
    
    return false;
  }

  /// Get time slot from hour (0-23 -> 0, 2, 4, ..., 22)
  int _getTimeSlot(int hour) {
    return (hour ~/ _slotDurationHours) * _slotDurationHours;
  }

  /// Get next morning time (8:00 AM)
  DateTime _getNextMorning(DateTime from) {
    var morning = DateTime(from.year, from.month, from.day, 8, 0);
    
    if (morning.isBefore(from)) {
      morning = morning.add(const Duration(days: 1));
    }
    
    return morning;
  }

  /// Get analytics data for UI display
  Future<NotificationAnalytics> getAnalytics() async {
    await _ensureInitialized();
    
    final events = _eventsBox!.values.toList();
    
    if (events.isEmpty) {
      return NotificationAnalytics.empty();
    }
    
    // Calculate metrics
    final totalNotifications = events.length;
    final openedCount = events.where((e) => e.wasOpened).length;
    final ignoredCount = events.where((e) => e.wasIgnored).length;
    final dismissedCount = events.where((e) => e.wasDismissed).length;
    
    final openRate = totalNotifications > 0
        ? openedCount / totalNotifications
        : 0.0;
    
    // Get probabilities per slot
    final probabilities = await _calculateProbabilities();
    
    // Calculate date range
    final timestamps = events.map((e) => e.timestamp).toList();
    timestamps.sort();
    final firstEventDate = timestamps.first;
    final lastEventDate = timestamps.last;
    
    return NotificationAnalytics(
      totalNotifications: totalNotifications,
      openedCount: openedCount,
      ignoredCount: ignoredCount,
      dismissedCount: dismissedCount,
      openRate: openRate,
      probabilitiesPerSlot: probabilities,
      hasEnoughData: _hasEnoughDataForLearning(),
      firstEventDate: firstEventDate,
      lastEventDate: lastEventDate,
    );
  }

  /// Update user preferences
  void updatePreferences({
    bool? smartNotificationsEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    if (smartNotificationsEnabled != null) {
      _smartNotificationsEnabled = smartNotificationsEnabled;
      debugPrint('⚙️ [SmartNotificationService] Smart notifications: ${_smartNotificationsEnabled ? "ENABLED" : "DISABLED"}');
    }
    
    if (quietStartHour != null) {
      _quietStartHour = quietStartHour.clamp(0, 23);
      debugPrint('⚙️ [SmartNotificationService] Quiet hours start: $_quietStartHour:00');
    }
    
    if (quietEndHour != null) {
      _quietEndHour = quietEndHour.clamp(0, 23);
      debugPrint('⚙️ [SmartNotificationService] Quiet hours end: $_quietEndHour:00');
    }
  }

  /// Get current preferences
  SmartNotificationPreferences getPreferences() {
    return SmartNotificationPreferences(
      smartNotificationsEnabled: _smartNotificationsEnabled,
      quietStartHour: _quietStartHour,
      quietEndHour: _quietEndHour,
    );
  }

  /// Clear all stored events (for testing or user reset)
  Future<void> clearAllEvents() async {
    await _ensureInitialized();
    await _eventsBox!.clear();
    _cachedProbabilities = null;
    debugPrint('🗑️ [SmartNotificationService] All events cleared');
  }

  /// Ensure service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _eventsBox?.close();
    _eventsBox = null;
    _initialized = false;
  }
}

/// Parameters for isolate communication
class _IsolateParams {
  final List<NotificationEvent> events;
  final SendPort sendPort;
  final double smoothing;

  _IsolateParams({
    required this.events,
    required this.sendPort,
    required this.smoothing,
  });
}

/// Analytics data for displaying in UI
class NotificationAnalytics {
  final int totalNotifications;
  final int openedCount;
  final int ignoredCount;
  final int dismissedCount;
  final double openRate;
  final Map<int, double> probabilitiesPerSlot;
  final bool hasEnoughData;
  final DateTime firstEventDate;
  final DateTime lastEventDate;

  NotificationAnalytics({
    required this.totalNotifications,
    required this.openedCount,
    required this.ignoredCount,
    required this.dismissedCount,
    required this.openRate,
    required this.probabilitiesPerSlot,
    required this.hasEnoughData,
    required this.firstEventDate,
    required this.lastEventDate,
  });

  factory NotificationAnalytics.empty() {
    return NotificationAnalytics(
      totalNotifications: 0,
      openedCount: 0,
      ignoredCount: 0,
      dismissedCount: 0,
      openRate: 0.0,
      probabilitiesPerSlot: {},
      hasEnoughData: false,
      firstEventDate: DateTime.now(),
      lastEventDate: DateTime.now(),
    );
  }

  int get daysTracked => lastEventDate.difference(firstEventDate).inDays;

  String get openRatePercentage => '${(openRate * 100).toStringAsFixed(1)}%';
}

/// User preferences for smart notifications
class SmartNotificationPreferences {
  final bool smartNotificationsEnabled;
  final int quietStartHour;
  final int quietEndHour;

  SmartNotificationPreferences({
    required this.smartNotificationsEnabled,
    required this.quietStartHour,
    required this.quietEndHour,
  });

  String get quietHoursDescription {
    return '${quietStartHour.toString().padLeft(2, '0')}:00 - ${quietEndHour.toString().padLeft(2, '0')}:00';
  }
}
