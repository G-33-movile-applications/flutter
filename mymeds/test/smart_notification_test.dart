import 'package:flutter_test/flutter_test.dart';
import 'package:mymeds/models/notification_event.dart';
import 'package:mymeds/services/smart_notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';


/// Mock PathProviderPlatform for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.test/hive';
  }

  @override
  Future<String?> getTemporaryPath() async {
    return '.test/temp';
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Set up mock path provider
    PathProviderPlatform.instance = MockPathProviderPlatform();
    
    // Initialize Hive for testing
    await Hive.initFlutter('.test/hive');
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  group('NotificationEvent Model', () {
    test('should create a notification event with all fields', () {
      final event = NotificationEvent(
        id: 'test-id',
        type: 'test_type',
        timestamp: DateTime(2024, 1, 1, 10, 30),
        result: NotificationResult.opened,
      );

      expect(event.id, equals('test-id'));
      expect(event.type, equals('test_type'));
      expect(event.result, equals(NotificationResult.opened));
      expect(event.hourOfDay, equals(10));
      expect(event.dayOfWeek, equals(1)); // Monday
    });

    test('should calculate correct time slot', () {
      final morning = NotificationEvent.create(
        type: 'test',
        result: NotificationResult.opened,
        timestamp: DateTime(2024, 1, 1, 9, 30), // 9:30 AM
      );

      final evening = NotificationEvent.create(
        type: 'test',
        result: NotificationResult.opened,
        timestamp: DateTime(2024, 1, 1, 20, 15), // 8:15 PM
      );

      expect(morning.timeSlot, equals(8)); // 8:00-10:00 slot
      expect(evening.timeSlot, equals(20)); // 20:00-22:00 slot
    });

    test('should identify opened notifications', () {
      final opened = NotificationEvent.create(
        type: 'test',
        result: NotificationResult.opened,
      );

      final ignored = NotificationEvent.create(
        type: 'test',
        result: NotificationResult.ignored,
      );

      expect(opened.wasOpened, isTrue);
      expect(ignored.wasOpened, isFalse);
      expect(ignored.wasIgnored, isTrue);
    });

    test('should generate readable time slot description', () {
      final event = NotificationEvent.create(
        type: 'test',
        result: NotificationResult.opened,
        timestamp: DateTime(2024, 1, 1, 14, 30), // 2:30 PM
      );

      expect(event.timeSlotDescription, equals('14:00-16:00'));
    });
  });

  group('SmartNotificationService - Initialization', () {
    late SmartNotificationService service;

    setUp(() {
      service = SmartNotificationService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should initialize successfully', () async {
      await service.initialize();
      
      // Service should be ready to use
      final prefs = service.getPreferences();
      expect(prefs.smartNotificationsEnabled, isTrue);
    });

    test('should not reinitialize if already initialized', () async {
      await service.initialize();
      
      // Should not throw when calling init again
      await service.initialize();
    });
  });

  group('SmartNotificationService - Event Recording', () {
    late SmartNotificationService service;

    setUp(() async {
      service = SmartNotificationService();
      await service.initialize();
    });

    tearDown(() async {
      await service.clearAllEvents();
      await service.dispose();
    });

    test('should record notification event', () async {
      await service.recordEvent(
        type: 'test',
        result: NotificationResult.opened,
      );

      final analytics = await service.getAnalytics();
      expect(analytics.totalNotifications, equals(1));
      expect(analytics.openedCount, equals(1));
    });

    test('should record multiple events', () async {
      for (int i = 0; i < 5; i++) {
        await service.recordEvent(
          type: 'test',
          result: i % 2 == 0 
              ? NotificationResult.opened 
              : NotificationResult.ignored,
        );
      }

      final analytics = await service.getAnalytics();
      expect(analytics.totalNotifications, equals(5));
      expect(analytics.openedCount, equals(3)); // 0, 2, 4
      expect(analytics.ignoredCount, equals(2)); // 1, 3
    });

    test('should calculate open rate correctly', () async {
      // Add 8 opened and 2 ignored (80% open rate)
      for (int i = 0; i < 10; i++) {
        await service.recordEvent(
          type: 'test',
          result: i < 8 
              ? NotificationResult.opened 
              : NotificationResult.ignored,
        );
      }

      final analytics = await service.getAnalytics();
      expect(analytics.openRate, closeTo(0.8, 0.01));
      expect(analytics.openRatePercentage, equals('80.0%'));
    });
  });

  group('SmartNotificationService - P(t) Calculation', () {
    late SmartNotificationService service;

    setUp(() async {
      service = SmartNotificationService();
      await service.initialize();
    });

    tearDown(() async {
      await service.clearAllEvents();
      await service.dispose();
    });

    test('should calculate probabilities with Laplace smoothing', () async {
      // Create events with 100% open rate in morning slot (8:00)
      for (int i = 0; i < 10; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.opened,
          timestamp: DateTime(2024, 1, i + 1, 9, 0), // All at 9:00 AM
        );
      }

      // Create events with 0% open rate in evening slot (20:00)
      for (int i = 0; i < 10; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.ignored,
          timestamp: DateTime(2024, 1, i + 1, 21, 0), // All at 9:00 PM
        );
      }

      final analytics = await service.getAnalytics();
      
      // Morning slot should have higher probability than evening
      final morningP = analytics.probabilitiesPerSlot[8]!;
      final eveningP = analytics.probabilitiesPerSlot[20]!;
      
      expect(morningP, greaterThan(eveningP));
      
      // With Laplace smoothing, probabilities should not be exactly 0 or 1
      expect(morningP, lessThan(1.0));
      expect(eveningP, greaterThan(0.0));
    });

    test('should handle empty dataset', () async {
      final analytics = await service.getAnalytics();
      
      expect(analytics.totalNotifications, equals(0));
      expect(analytics.hasEnoughData, isFalse);
    });

    test('should require minimum data for learning', () async {
      // Add only 5 events (less than minimum 20)
      for (int i = 0; i < 5; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.opened,
          timestamp: DateTime(2024, 1, i + 1, 9, 0),
        );
      }

      final analytics = await service.getAnalytics();
      expect(analytics.hasEnoughData, isFalse);
    });

    test('should require minimum time span for learning', () async {
      // Add 25 events but all on same day (less than minimum 7 days)
      for (int i = 0; i < 25; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.opened,
          timestamp: DateTime(2024, 1, 1, i % 24, 0),
        );
      }

      final analytics = await service.getAnalytics();
      expect(analytics.hasEnoughData, isFalse);
    });

    test('should detect sufficient data for learning', () async {
      // Add 25 events over 8 days
      for (int day = 0; day < 8; day++) {
        for (int i = 0; i < 3; i++) {
          await service.recordEvent(
            type: 'test',
            result: NotificationResult.opened,
            timestamp: DateTime(2024, 1, day + 1, 9 + i, 0),
          );
        }
      }

      final analytics = await service.getAnalytics();
      expect(analytics.hasEnoughData, isTrue);
      expect(analytics.daysTracked, greaterThanOrEqualTo(7));
    });
  });

  group('SmartNotificationService - Scheduling Logic', () {
    late SmartNotificationService service;

    setUp(() async {
      service = SmartNotificationService();
      await service.initialize();
    });

    tearDown(() async {
      await service.clearAllEvents();
      await service.dispose();
    });

    test('should send urgent notifications immediately', () async {
      final shouldSend = await service.shouldSendNotificationNow(
        type: 'urgent_test',
        isUrgent: true,
      );

      expect(shouldSend, isTrue);
    });

    test('should respect quiet hours', () async {
      // Set quiet hours from 22:00 to 7:00
      service.updatePreferences(
        quietStartHour: 22,
        quietEndHour: 7,
      );

      // Test during quiet hours (2:00 AM)
      final shouldSendAtNight = await service.shouldSendNotificationNow(
        type: 'test',
        isUrgent: false,
        proposedTime: DateTime(2024, 1, 1, 2, 0),
      );

      // Test outside quiet hours (10:00 AM)
      final shouldSendAtDay = await service.shouldSendNotificationNow(
        type: 'test',
        isUrgent: false,
        proposedTime: DateTime(2024, 1, 1, 10, 0),
      );

      expect(shouldSendAtNight, isFalse);
      expect(shouldSendAtDay, isTrue);
    });

    test('should use default rules when insufficient data', () async {
      // No events recorded, should use default rules
      final shouldSend = await service.shouldSendNotificationNow(
        type: 'test',
        isUrgent: false,
        proposedTime: DateTime(2024, 1, 1, 10, 0), // Morning
      );

      expect(shouldSend, isTrue); // Default: send if not in quiet hours
    });

    test('should suggest optimal send time', () async {
      // Create pattern: high engagement in morning (8:00-10:00)
      for (int i = 0; i < 25; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.opened,
          timestamp: DateTime(2024, 1, (i % 10) + 1, 9, 0),
        );
      }

      // Create pattern: low engagement in evening (20:00-22:00)
      for (int i = 0; i < 15; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.ignored,
          timestamp: DateTime(2024, 1, (i % 10) + 1, 21, 0),
        );
      }

      // Request optimal time for evening notification
      final optimalTime = await service.getOptimalSendTime(
        afterTime: DateTime(2024, 1, 15, 20, 0),
      );

      // Should suggest morning slot (next day)
      expect(optimalTime.hour, equals(8));
      expect(optimalTime.isAfter(DateTime(2024, 1, 15, 20, 0)), isTrue);
    });
  });

  group('SmartNotificationService - Preferences', () {
    late SmartNotificationService service;

    setUp(() async {
      service = SmartNotificationService();
      await service.initialize();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should update smart notifications enabled state', () {
      service.updatePreferences(smartNotificationsEnabled: false);
      
      final prefs = service.getPreferences();
      expect(prefs.smartNotificationsEnabled, isFalse);
    });

    test('should update quiet hours', () {
      service.updatePreferences(
        quietStartHour: 23,
        quietEndHour: 6,
      );
      
      final prefs = service.getPreferences();
      expect(prefs.quietStartHour, equals(23));
      expect(prefs.quietEndHour, equals(6));
    });

    test('should clamp quiet hours to valid range', () {
      service.updatePreferences(
        quietStartHour: 30, // Invalid, should clamp to 23
        quietEndHour: -5,   // Invalid, should clamp to 0
      );
      
      final prefs = service.getPreferences();
      expect(prefs.quietStartHour, equals(23));
      expect(prefs.quietEndHour, equals(0));
    });

    test('should provide quiet hours description', () {
      service.updatePreferences(
        quietStartHour: 22,
        quietEndHour: 7,
      );
      
      final prefs = service.getPreferences();
      expect(prefs.quietHoursDescription, equals('22:00 - 07:00'));
    });
  });

  group('SmartNotificationService - Edge Cases', () {
    late SmartNotificationService service;

    setUp(() async {
      service = SmartNotificationService();
      await service.initialize();
    });

    tearDown(() async {
      await service.clearAllEvents();
      await service.dispose();
    });

    test('should handle midnight boundary in quiet hours', () {
      service.updatePreferences(
        quietStartHour: 22,
        quietEndHour: 7,
      );

      // Test times around midnight
      final beforeMidnight = DateTime(2024, 1, 1, 23, 30);
      final afterMidnight = DateTime(2024, 1, 2, 1, 30);
      final morning = DateTime(2024, 1, 2, 8, 0);

      expect(
        service.shouldSendNotificationNow(
          type: 'test',
          proposedTime: beforeMidnight,
        ).then((result) => result),
        completion(isFalse),
      );

      expect(
        service.shouldSendNotificationNow(
          type: 'test',
          proposedTime: afterMidnight,
        ).then((result) => result),
        completion(isFalse),
      );

      expect(
        service.shouldSendNotificationNow(
          type: 'test',
          proposedTime: morning,
        ).then((result) => result),
        completion(isTrue),
      );
    });

    test('should clear all events', () async {
      // Add some events
      for (int i = 0; i < 10; i++) {
        await service.recordEvent(
          type: 'test',
          result: NotificationResult.opened,
        );
      }

      // Verify events exist
      var analytics = await service.getAnalytics();
      expect(analytics.totalNotifications, equals(10));

      // Clear all events
      await service.clearAllEvents();

      // Verify events cleared
      analytics = await service.getAnalytics();
      expect(analytics.totalNotifications, equals(0));
    });

    test('should handle different notification types', () async {
      await service.recordEvent(
        type: 'prescription_reminder',
        result: NotificationResult.opened,
      );

      await service.recordEvent(
        type: 'order_update',
        result: NotificationResult.ignored,
      );

      await service.recordEvent(
        type: 'delivery_status',
        result: NotificationResult.dismissed,
      );

      final analytics = await service.getAnalytics();
      expect(analytics.totalNotifications, equals(3));
      expect(analytics.openedCount, equals(1));
      expect(analytics.ignoredCount, equals(1));
      expect(analytics.dismissedCount, equals(1));
    });
  });
}
