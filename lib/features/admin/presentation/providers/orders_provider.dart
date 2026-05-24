import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../domain/models/order.dart';
import 'techs_provider.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return SupabaseOrdersRepository(Supabase.instance.client);
});

// تحديث دوري (Polling) للطلبات باستخدام الثابت المعرف في النظام
final ordersStreamProvider = StreamProvider<List<Order>>((ref) async* {
  final repo = ref.watch(ordersRepositoryProvider);
  
  yield await repo.getAll();
  
  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) => repo.getAll());
});

// تحديث دوري لطلبات الفني المحدد
final techOrdersStreamProvider = StreamProvider.family<List<Order>, String>((ref, techId) async* {
  final repo = ref.watch(ordersRepositoryProvider);
  
  yield await repo.getOrdersByTech(techId).then((value) => value.getRight() ?? []);
  
  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) async {
    final result = await repo.getOrdersByTech(techId);
    return result.getRight() ?? [];
  });
});

final ordersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(ordersRepositoryProvider).getAll();
});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? [];
  final techs = ref.watch(techsStreamProvider).valueOrNull ?? [];
  
  return DashboardStats(
    totalOrders: orders.length,
    pendingOrders: orders.where((o) => o.status == OrderStatus.pending).length,
    completedOrders: orders.where((o) => o.status == OrderStatus.completed).length,
    cancelledOrders: orders.where((o) => o.status == OrderStatus.cancelled).length,
    totalTechs: techs.length,
    availableTechs: techs.where((t) => t.status == TechStatus.available).length,
    busyTechs: techs.where((t) => t.status == TechStatus.busy).length,
    onLeaveTechs: techs.where((t) => t.status == TechStatus.onLeave).length,
    pendingTechs: techs.where((t) => t.status == TechStatus.pending).length,
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
    'techPending': stats.pendingTechs,
  };
});
