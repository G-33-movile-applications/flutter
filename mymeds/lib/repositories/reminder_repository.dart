import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/medication_reminder.dart';

/// Repository for managing medication reminders in Firestore
/// 
/// Stores reminders in: usuarios/{userId}/recordatoriosMedicamentos/{reminderId}
class ReminderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reminders collection reference for a user
  CollectionReference<Map<String, dynamic>> _getRemindersCollection(String userId) {
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .collection('recordatoriosMedicamentos');
  }

  /// Get all reminders for a user
  Future<List<MedicationReminder>> getUserReminders(String userId) async {
    try {
      debugPrint('🔍 [ReminderRepository] Fetching reminders for user: $userId');
      
      final snapshot = await _getRemindersCollection(userId).get();
      
      final reminders = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              data['id'] = doc.id; // Ensure ID is set from document ID
              return MedicationReminder.fromJson(data);
            } catch (e) {
              debugPrint('⚠️ [ReminderRepository] Error parsing reminder ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MedicationReminder>()
          .toList();
      
      debugPrint('✅ [ReminderRepository] Fetched ${reminders.length} reminders');
      return reminders;
    } catch (e) {
      debugPrint('❌ [ReminderRepository] Error fetching reminders: $e');
      rethrow;
    }
  }

  /// Create a new reminder
  Future<MedicationReminder> createReminder(String userId, MedicationReminder reminder) async {
    try {
      debugPrint('➕ [ReminderRepository] Creating reminder: ${reminder.medicineName}');
      
      final docRef = reminder.id.isEmpty
          ? _getRemindersCollection(userId).doc()
          : _getRemindersCollection(userId).doc(reminder.id);
      
      final reminderWithId = reminder.copyWith(id: docRef.id);
      final data = reminderWithId.toJson();
      
      await docRef.set(data);
      
      debugPrint('✅ [ReminderRepository] Created reminder: ${docRef.id}');
      return reminderWithId;
    } catch (e) {
      debugPrint('❌ [ReminderRepository] Error creating reminder: $e');
      rethrow;
    }
  }

  /// Update an existing reminder
  Future<void> updateReminder(String userId, MedicationReminder reminder) async {
    try {
      debugPrint('🔄 [ReminderRepository] Updating reminder: ${reminder.id}');
      
      await _getRemindersCollection(userId)
          .doc(reminder.id)
          .update(reminder.toJson());
      
      debugPrint('✅ [ReminderRepository] Updated reminder: ${reminder.id}');
    } catch (e) {
      debugPrint('❌ [ReminderRepository] Error updating reminder: $e');
      rethrow;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String userId, String reminderId) async {
    try {
      debugPrint('🗑️ [ReminderRepository] Deleting reminder: $reminderId');
      
      await _getRemindersCollection(userId).doc(reminderId).delete();
      
      debugPrint('✅ [ReminderRepository] Deleted reminder: $reminderId');
    } catch (e) {
      debugPrint('❌ [ReminderRepository] Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Get a single reminder by ID
  Future<MedicationReminder?> getReminderById(String userId, String reminderId) async {
    try {
      debugPrint('🔍 [ReminderRepository] Fetching reminder: $reminderId');
      
      final doc = await _getRemindersCollection(userId).doc(reminderId).get();
      
      if (!doc.exists) {
        debugPrint('⚠️ [ReminderRepository] Reminder not found: $reminderId');
        return null;
      }
      
      final data = doc.data()!;
      data['id'] = doc.id;
      
      return MedicationReminder.fromJson(data);
    } catch (e) {
      debugPrint('❌ [ReminderRepository] Error fetching reminder: $e');
      rethrow;
    }
  }

  /// Stream reminders for real-time updates
  Stream<List<MedicationReminder>> streamUserReminders(String userId) {
    return _getRemindersCollection(userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              data['id'] = doc.id;
              return MedicationReminder.fromJson(data);
            } catch (e) {
              debugPrint('⚠️ [ReminderRepository] Error parsing reminder ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MedicationReminder>()
          .toList();
    });
  }

  /// Batch update multiple reminders (for sync operations)
  Future<void> batchUpdateReminders(String userId, List<MedicationReminder> reminders) async {
    try {
      debugPrint('📦 [ReminderRepository] Batch updating ${reminders.length} reminders');
      
      final batch = _firestore.batch();
      
      for (final reminder in reminders) {
        final docRef = _getRemindersCollection(userId).doc(reminder.id);
        batch.set(docRef, reminder.toJson(), SetOptions(merge: true));
      }
      
      await batch.commit();
      
      debugPrint('✅ [ReminderRepository] Batch update completed');
    } catch (e) {
      debugPrint('❌ [ReminderRepository] Error in batch update: $e');
      rethrow;
    }
  }
}
