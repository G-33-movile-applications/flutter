import '../models/delivery_stats.dart';
import '../repositories/pedido_repository.dart';

class AnalyticsService {
  final PedidoRepository _pedidoRepository = PedidoRepository();

  /// Get delivery vs pickup statistics
  Future<DeliveryStats> getDeliveryStats({DateTime? startDate, DateTime? endDate}) async {
    try {
      print('Analytics - Starting to fetch stats');
      print('Analytics - Start date: ${startDate?.toIso8601String()}');
      print('Analytics - End date: ${endDate?.toIso8601String()}');

      // Get all orders
      final pedidos = await _pedidoRepository.readAll();
      print('Analytics - Found ${pedidos.length} total orders');

      // Filter by date if needed
      final filteredPedidos = pedidos.where((pedido) {
        if (startDate != null && pedido.fechaDespacho.isBefore(startDate)) return false;
        if (endDate != null && pedido.fechaDespacho.isAfter(endDate)) return false;
        return true;
      }).toList();
      
      print('Analytics - After date filtering: ${filteredPedidos.length} orders');
    
      int deliveryCount = 0;
      int pickupCount = 0;
      Map<String, int> deliveryByMonth = {};
      Map<String, int> pickupByMonth = {};

      for (var pedido in filteredPedidos) {
        final date = pedido.fechaDespacho;
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        print('Analytics - Processing order ${pedido.identificadorPedido} - entregaEnTienda: ${pedido.entregaEnTienda}');

        if (!pedido.entregaEnTienda) {
          deliveryCount++;
          deliveryByMonth[monthKey] = (deliveryByMonth[monthKey] ?? 0) + 1;
          print('Analytics - Counted as DELIVERY');
        } else {
          pickupCount++;
          pickupByMonth[monthKey] = (pickupByMonth[monthKey] ?? 0) + 1;
          print('Analytics - Counted as PICKUP');
        }
      }

      print('Analytics - Final counts: Delivery=$deliveryCount, Pickup=$pickupCount');

      return DeliveryStats(
        totalOrders: filteredPedidos.length,
        deliveryCount: deliveryCount,
        pickupCount: pickupCount,
        deliveryByMonth: deliveryByMonth,
        pickupByMonth: pickupByMonth,
      );
    } catch (e, stack) {
      print('Analytics - Error fetching stats: $e');
      print(stack);
      rethrow;
    }
  }

  /// Get statistics for a specific pharmacy
  Future<DeliveryStats> getPharmacyDeliveryStats(String pharmacyId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      print('Analytics - Starting to fetch pharmacy stats for ID: $pharmacyId');

      // Get all orders
      final allPedidos = await _pedidoRepository.readAll();
      print('Analytics - Found ${allPedidos.length} total orders');

      // Filter for this pharmacy and date range
      final pedidos = allPedidos.where((pedido) {
        if (pedido.puntoFisicoId != pharmacyId) return false;
        if (startDate != null && pedido.fechaDespacho.isBefore(startDate)) return false;
        if (endDate != null && pedido.fechaDespacho.isAfter(endDate)) return false;
        return true;
      }).toList();
      
      print('Analytics - Found ${pedidos.length} orders for this pharmacy');
      
      int deliveryCount = 0;
      int pickupCount = 0;
      Map<String, int> deliveryByMonth = {};
      Map<String, int> pickupByMonth = {};

      for (var pedido in pedidos) {
        final date = pedido.fechaDespacho;
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        print('Analytics - Processing order ${pedido.identificadorPedido} - entregaEnTienda: ${pedido.entregaEnTienda}');

        if (!pedido.entregaEnTienda) {
          deliveryCount++;
          deliveryByMonth[monthKey] = (deliveryByMonth[monthKey] ?? 0) + 1;
          print('Analytics - Counted as DELIVERY');
        } else {
          pickupCount++;
          pickupByMonth[monthKey] = (pickupByMonth[monthKey] ?? 0) + 1;
          print('Analytics - Counted as PICKUP');
        }
      }

      print('Analytics - Final pharmacy counts: Delivery=$deliveryCount, Pickup=$pickupCount');

      return DeliveryStats(
        totalOrders: pedidos.length,
        deliveryCount: deliveryCount,
        pickupCount: pickupCount,
        deliveryByMonth: deliveryByMonth,
        pickupByMonth: pickupByMonth,
      );
    } catch (e, stack) {
      print('Analytics - Error fetching pharmacy stats: $e');
      print(stack);
      rethrow;
    }
  }
}