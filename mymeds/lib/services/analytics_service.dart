import '../models/delivery_stats.dart';
import '../repositories/pedido_repository.dart';

class AnalyticsService {
  final PedidoRepository _pedidoRepository = PedidoRepository();

  /// Get delivery vs pickup statistics for a specific user
  Future<DeliveryStats> getDeliveryStats({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      

      // Get orders for the specific user
      final pedidos = await _pedidoRepository.readAll(userId: userId);
      

      // Filter by date if needed
      final filteredPedidos = pedidos.where((pedido) {
        if (startDate != null && pedido.fechaDespacho.isBefore(startDate)) return false;
        if (endDate != null && pedido.fechaDespacho.isAfter(endDate)) return false;
        return true;
      }).toList();
      
      
    
      int deliveryCount = 0;
      int pickupCount = 0;
      Map<String, int> deliveryByMonth = {};
      Map<String, int> pickupByMonth = {};

      for (var pedido in filteredPedidos) {
        final date = pedido.fechaDespacho;
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        

        if (!pedido.entregaEnTienda) {
          deliveryCount++;
          deliveryByMonth[monthKey] = (deliveryByMonth[monthKey] ?? 0) + 1;
         
        } else {
          pickupCount++;
          pickupByMonth[monthKey] = (pickupByMonth[monthKey] ?? 0) + 1;
          
        }
      }

      

      return DeliveryStats(
        totalOrders: filteredPedidos.length,
        deliveryCount: deliveryCount,
        pickupCount: pickupCount,
        deliveryByMonth: deliveryByMonth,
        pickupByMonth: pickupByMonth,
      );
    } catch (e) {
      
      rethrow;
    }
  }

  /// Get statistics for a specific pharmacy
  Future<DeliveryStats> getPharmacyDeliveryStats(String pharmacyId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      

      // Get all orders
      final allPedidos = await _pedidoRepository.readAll();
      

      // Filter for this pharmacy and date range
      final pedidos = allPedidos.where((pedido) {
        if (pedido.puntoFisicoId != pharmacyId) return false;
        if (startDate != null && pedido.fechaDespacho.isBefore(startDate)) return false;
        if (endDate != null && pedido.fechaDespacho.isAfter(endDate)) return false;
        return true;
      }).toList();
      
  
      
      int deliveryCount = 0;
      int pickupCount = 0;
      Map<String, int> deliveryByMonth = {};
      Map<String, int> pickupByMonth = {};

      for (var pedido in pedidos) {
        final date = pedido.fechaDespacho;
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
       

        if (!pedido.entregaEnTienda) {
          deliveryCount++;
          deliveryByMonth[monthKey] = (deliveryByMonth[monthKey] ?? 0) + 1;
          
        } else {
          pickupCount++;
          pickupByMonth[monthKey] = (pickupByMonth[monthKey] ?? 0) + 1;
          
        }
      }

      

      return DeliveryStats(
        totalOrders: pedidos.length,
        deliveryCount: deliveryCount,
        pickupCount: pickupCount,
        deliveryByMonth: deliveryByMonth,
        pickupByMonth: pickupByMonth,
      );
    } catch (e) {
      
      rethrow;
    }
  }
}