import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../domain/models/order.dart';
import 'techs_provider.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return SupabaseOrdersRepository(Supabase.instance.client);
});

final ordersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(ordersRepositoryProvider).getAll();
});

final ordersStreamProvider = ordersProvider;

final ordersByStatusProvider = Provider.family<List<Order>, OrderStatus>((
  ref,
  status,
) {
  final orders = ref.watch(ordersProvider).valueOrNull ?? [];
  return orders.where((o) => o.status == status).toList();
});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final orders = ref.watch(ordersProvider).valueOrNull ?? [];
  final techs = ref.watch(techniciansProvider).valueOrNull ?? [];
  return DashboardStats(
    totalOrders: orders.length,
    pendingOrders: orders.where((o) => o.status == OrderStatus.pending).length,
    completedOrders: orders
        .where((o) => o.status == OrderStatus.completed)
        .length,
    cancelledOrders: orders
        .where((o) => o.status == OrderStatus.cancelled)
        .length,
    totalTechs: techs.length,
    availableTechs: techs.where((t) => t.status == TechStatus.available).length,
    busyTechs: techs.where((t) => t.status == TechStatus.busy).length,
    onLeaveTechs: techs.where((t) => t.status == TechStatus.onLeave).length,
  );
});

final statsProvider = Provider((ref) {
  final stats = ref.watch(dashboardStatsProvider);
  return {
    'total': stats.totalOrders,
    'pending': stats.pendingOrders,
    'completed': stats.completedOrders,
    'techTotal': stats.totalTechs,
    'techAvailable': stats.availableTechs,
  };
});
