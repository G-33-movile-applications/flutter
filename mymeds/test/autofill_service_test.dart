import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mymeds/services/autofill_service.dart';
import 'package:mymeds/models/autofill_entry.dart';

void main() {
  group('AutofillService Tests', () {
    late AutofillService autofillService;

    setUp(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();
      
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(AutofillEntryAdapter());
      }
      
      autofillService = AutofillService();
      await autofillService.initialize();
      
      // Clear any existing data
      await autofillService.clearAllHistory();
    });

    tearDown(() async {
      await autofillService.dispose();
    });

    test('AutofillService initializes successfully', () {
      expect(autofillService.isEnabled, isTrue);
    });

    test('Recording selection increments count', () async {
      // Record the same selection multiple times
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );

      // Get suggestions
      final suggestions = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'address_type',
        topN: 1,
      );

      expect(suggestions.length, 1);
      expect(suggestions.first, 'home');
    });

    test('Top-N suggestions are returned correctly', () async {
      // Record different selections with varying frequencies
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'current',
      );
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'current',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'other',
      );

      // Get top 3 suggestions
      final suggestions = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'address_type',
        topN: 3,
      );

      expect(suggestions.length, 3);
      expect(suggestions[0], 'home'); // Most frequent
      expect(suggestions[1], 'current'); // Second most frequent
      expect(suggestions[2], 'other'); // Least frequent
    });

    test('Suggestions are entity-specific', () async {
      // Record selections for different entities
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );
      
      await autofillService.recordSelection(
        entity: 'profile',
        field: 'mode',
        value: 'edit',
      );

      // Get suggestions for delivery entity
      final deliverySuggestions = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'mode',
        topN: 5,
      );

      // Get suggestions for profile entity
      final profileSuggestions = await autofillService.getSuggestions(
        entity: 'profile',
        field: 'mode',
        topN: 5,
      );

      expect(deliverySuggestions.contains('pickup'), isTrue);
      expect(deliverySuggestions.contains('edit'), isFalse);
      
      expect(profileSuggestions.contains('edit'), isTrue);
      expect(profileSuggestions.contains('pickup'), isFalse);
    });

    test('Sensitive fields are not tracked', () async {
      await autofillService.recordSelection(
        entity: 'payment',
        field: 'credit_card',
        value: '1234567890123456',
      );
      
      await autofillService.recordSelection(
        entity: 'auth',
        field: 'password',
        value: 'mySecretPassword',
      );

      final paymentSuggestions = await autofillService.getSuggestions(
        entity: 'payment',
        field: 'credit_card',
        topN: 5,
      );
      
      final authSuggestions = await autofillService.getSuggestions(
        entity: 'auth',
        field: 'password',
        topN: 5,
      );

      // Sensitive fields should not have suggestions
      expect(paymentSuggestions.isEmpty, isTrue);
      expect(authSuggestions.isEmpty, isTrue);
    });

    test('Empty values are not recorded', () async {
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address',
        value: '',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address',
        value: '   ',
      );

      final suggestions = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'address',
        topN: 5,
      );

      expect(suggestions.isEmpty, isTrue);
    });

    test('Enable/disable autofill works correctly', () async {
      // Disable autofill
      await autofillService.setEnabled(false);
      expect(autofillService.isEnabled, isFalse);

      // Try to record a selection
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );

      // Should have no suggestions because autofill is disabled
      final suggestionsDisabled = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'mode',
        topN: 5,
      );
      expect(suggestionsDisabled.isEmpty, isTrue);

      // Re-enable autofill
      await autofillService.setEnabled(true);
      expect(autofillService.isEnabled, isTrue);

      // Record selection again
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );

      // Should have suggestions now
      final suggestionsEnabled = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'mode',
        topN: 5,
      );
      expect(suggestionsEnabled.isNotEmpty, isTrue);
    });

    test('Clear history removes all entries', () async {
      // Record multiple selections
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      
      await autofillService.recordSelection(
        entity: 'profile',
        field: 'theme',
        value: 'dark',
      );

      // Clear all history
      await autofillService.clearAllHistory();

      // Should have no suggestions after clearing
      final deliverySuggestions = await autofillService.getSuggestions(
        entity: 'delivery',
        field: 'mode',
        topN: 5,
      );
      
      final profileSuggestions = await autofillService.getSuggestions(
        entity: 'profile',
        field: 'theme',
        topN: 5,
      );

      expect(deliverySuggestions.isEmpty, isTrue);
      expect(profileSuggestions.isEmpty, isTrue);
    });

    test('GetTopSuggestion returns the most frequent value', () async {
      // Record selections with different frequencies
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'delivery',
      );

      final topSuggestion = await autofillService.getTopSuggestion(
        entity: 'delivery',
        field: 'mode',
      );

      expect(topSuggestion, 'pickup');
    });

    test('Statistics are calculated correctly', () async {
      // Record some selections
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
      );
      
      await autofillService.recordSelection(
        entity: 'delivery',
        field: 'address_type',
        value: 'home',
      );
      
      await autofillService.recordSelection(
        entity: 'profile',
        field: 'theme',
        value: 'dark',
      );

      final stats = autofillService.getStatistics();
      
      expect(stats['totalEntries'], greaterThan(0));
      expect(stats['activeEntries'], greaterThan(0));
      expect(stats['entitiesCovered'], greaterThanOrEqualTo(2)); // delivery and profile
      expect(stats['fieldsCovered'], greaterThanOrEqualTo(3)); // mode, address_type, theme
      expect(stats['isEnabled'], isTrue);
    });
  });

  group('AutofillEntry Model Tests', () {
    test('AutofillEntry calculates age correctly', () {
      final entry = AutofillEntry(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
        count: 5,
        lastUsed: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(entry.ageInDays, 10);
    });

    test('AutofillEntry weighted score decreases with age', () {
      final recentEntry = AutofillEntry(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
        count: 5,
        lastUsed: DateTime.now(),
      );

      final oldEntry = AutofillEntry(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
        count: 5,
        lastUsed: DateTime.now().subtract(const Duration(days: 30)),
      );

      expect(recentEntry.weightedScore, greaterThan(oldEntry.weightedScore));
    });

    test('AutofillEntry identifies stale entries correctly', () {
      final freshEntry = AutofillEntry(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
        count: 5,
        lastUsed: DateTime.now(),
      );

      final staleEntry = AutofillEntry(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
        count: 5,
        lastUsed: DateTime.now().subtract(const Duration(days: 100)),
      );

      expect(freshEntry.isStale, isFalse);
      expect(staleEntry.isStale, isTrue);
    });

    test('AutofillEntry generates correct composite key', () {
      final entry = AutofillEntry(
        entity: 'delivery',
        field: 'mode',
        value: 'pickup',
        count: 1,
        lastUsed: DateTime.now(),
      );

      expect(entry.key, 'delivery_mode_pickup');
    });
  });
}
