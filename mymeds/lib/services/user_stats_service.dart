import '../models/user_stats.dart';
import '../models/pedido.dart';
import '../repositories/punto_fisico_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatsService {
  final PuntoFisicoRepository _puntoFisicoRepository = PuntoFisicoRepository();

  /// Get user-specific statistics about their orders and preferences
  Future<UserStats> getUserStats(String userId) async {
    try {
      print('📊 UserStatsService - Fetching stats for user: $userId');

      // Get all orders for this specific user from their subcollection
      final pedidosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('pedidos')
          .get();

      final pedidos = pedidosSnapshot.docs
          .map((doc) => Pedido.fromMap(doc.data(), documentId: doc.id))
          .toList();

      print('📊 UserStatsService - Found ${pedidos.length} orders for user');

      if (pedidos.isEmpty) {
        return UserStats.empty();
      }

      int deliveryCount = 0;
      int pickupCount = 0;
      Map<String, int> pharmacyOrderCounts = {};

      // Analyze each order
      for (var pedido in pedidos) {
        // Count delivery vs pickup
        if (pedido.tipoEntrega == 'domicilio') {
          deliveryCount++;
        } else {
          pickupCount++;
        }

        // Count orders per pharmacy
        if (pedido.puntoFisicoId.isNotEmpty) {
          pharmacyOrderCounts[pedido.puntoFisicoId] = 
              (pharmacyOrderCounts[pedido.puntoFisicoId] ?? 0) + 1;
        }
      }

      // Find most frequent pharmacy
      String? mostFrequentPharmacyId;
      int maxCount = 0;
      pharmacyOrderCounts.forEach((pharmacyId, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequentPharmacyId = pharmacyId;
        }
      });

      // Get pharmacy name if found
      String? mostFrequentPharmacyName;
      if (mostFrequentPharmacyId != null) {
        try {
          final pharmacy = await _puntoFisicoRepository.read(mostFrequentPharmacyId!);
          mostFrequentPharmacyName = pharmacy?.nombre;
        } catch (e) {
          print('⚠️ UserStatsService - Error fetching pharmacy name: $e');
        }
      }

      // Determine preferred delivery mode
      final preferredMode = deliveryCount >= pickupCount ? 'domicilio' : 'recogida';

      // Business Question Type 2: Calculate medicine statistics
      int totalMedicinesRequested = 0;
      DateTime? lastClaimDate;

      // Get all prescriptions for this user
      final prescripcionesSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('prescripciones')
          .get();

      print('📊 UserStatsService - Found ${prescripcionesSnapshot.docs.length} prescriptions');

      // Count medicines in parallel (MUCH faster than sequential)
      final medicineFutures = prescripcionesSnapshot.docs.map((prescDoc) async {
        try {
          final medicamentosSnapshot = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(userId)
              .collection('prescripciones')
              .doc(prescDoc.id)
              .collection('medicamentos')
              .get();
          
          final count = medicamentosSnapshot.docs.length;
          print('📊 UserStatsService - Prescription ${prescDoc.id}: $count medicines');
          return count;
        } catch (e) {
          print('⚠️ UserStatsService - Error counting medicines for prescription ${prescDoc.id}: $e');
          return 0;
        }
      }).toList();

      // Wait for all queries to complete in parallel
      final medicineCounts = await Future.wait(medicineFutures);
      totalMedicinesRequested = medicineCounts.fold(0, (sum, count) => sum + count);

      // Find most recent delivery date from delivered orders
      for (var pedido in pedidos) {
        if (pedido.fechaEntrega != null) {
          if (lastClaimDate == null || pedido.fechaEntrega!.isAfter(lastClaimDate)) {
            lastClaimDate = pedido.fechaEntrega;
          }
        }
      }

      print('📊 UserStatsService - Stats calculated: delivery=$deliveryCount, pickup=$pickupCount');
      print('📊 UserStatsService - Most frequent pharmacy: $mostFrequentPharmacyName');
      print('📊 UserStatsService - Total medicines requested: $totalMedicinesRequested');
      print('📊 UserStatsService - Last claim date: $lastClaimDate');

      return UserStats(
        totalOrders: pedidos.length,
        deliveryCount: deliveryCount,
        pickupCount: pickupCount,
        pharmacyOrderCounts: pharmacyOrderCounts,
        mostFrequentPharmacyId: mostFrequentPharmacyId,
        mostFrequentPharmacyName: mostFrequentPharmacyName,
        preferredDeliveryMode: preferredMode,
        totalMedicinesRequested: totalMedicinesRequested,
        lastClaimDate: lastClaimDate,
      );
    } catch (e, stack) {
      print('❌ UserStatsService - Error fetching user stats: $e');
      print(stack);
      rethrow;
    }
  }

  /// Get top N pharmacies by order count for a user
  /// Optimized version that accepts pre-calculated stats to avoid duplicate queries
  Future<List<Map<String, dynamic>>> getTopPharmacies(String userId, {int limit = 5, UserStats? stats}) async {
    try {
      // Use provided stats or fetch them (avoid duplicate query)
      final userStats = stats ?? await getUserStats(userId);
      
      // Sort pharmacies by order count
      var sortedPharmacies = userStats.pharmacyOrderCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Take top N
      if (sortedPharmacies.length > limit) {
        sortedPharmacies = sortedPharmacies.take(limit).toList();
      }

      // Fetch pharmacy details in parallel (much faster)
      final pharmacyFutures = sortedPharmacies.map((entry) async {
        try {
          final pharmacy = await _puntoFisicoRepository.read(entry.key);
          if (pharmacy != null) {
            return {
              'pharmacy': pharmacy,
              'orderCount': entry.value,
            };
          }
        } catch (e) {
          print('⚠️ Error fetching pharmacy ${entry.key}: $e');
        }
        return null;
      }).toList();

      final results = await Future.wait(pharmacyFutures);
      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      print('❌ UserStatsService - Error fetching top pharmacies: $e');
      rethrow;
    }
  }
}
