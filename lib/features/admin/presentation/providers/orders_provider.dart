import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// مفتاح التخزين المؤقت
const _ordersCacheKey = 'cached_orders_list';

// تحديث دوري (Polling) للطلبات مع دعم الكاش
final ordersStreamProvider = StreamProvider<List<Order>>((ref) async* {
  final repo = ref.watch(ordersRepositoryProvider);
  final prefs = await SharedPreferences.getInstance();

  // 1. استرجاع البيانات المخزنة مؤقتاً فوراً (Offline Support)
  final cachedData = prefs.getString(_ordersCacheKey);
  if (cachedData != null) {
    try {
      final List decoded = jsonDecode(cachedData);
      yield decoded.map((e) => Order.fromJson(e)).toList();
    } catch (_) {}
  }

  // 2. محاولة جلب البيانات الجديدة وحفظها
  Future<List<Order>> fetchAndCache() async {
    try {
      final orders = await repo.getAll();
      // حفظ النسخة الجديدة في الكاش
      await prefs.setString(_ordersCacheKey, jsonEncode(orders.map((o) => o.toJson()).toList()));
      return orders;
    } catch (e) {
      // في حال الخطأ نرجع النسخة القديمة إذا وجدت
      if (cachedData != null) {
        try {
          final List decoded = jsonDecode(cachedData);
          return decoded.map((e) => Order.fromJson(e)).toList();
        } catch (_) {}
      }
      rethrow;
    }
  }

  yield await fetchAndCache();

  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) => fetchAndCache());
});

// تحديث دوري لطلبات الفني المحدد مع دعم الكاش
final techOrdersStreamProvider = StreamProvider.family<List<Order>, String>((ref, techId) async* {
  final repo = ref.watch(ordersRepositoryProvider);
  final prefs = await SharedPreferences.getInstance();
  final cacheKey = 'tech_orders_$techId';

  final cachedData = prefs.getString(cacheKey);
  if (cachedData != null) {
    try {
      final List decoded = jsonDecode(cachedData);
      yield decoded.map((e) => Order.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<List<Order>> fetch() async {
    final result = await repo.getOrdersByTech(techId);
    return result.when(
      left: (failure) {
         if (cachedData != null) {
           try {
             final List decoded = jsonDecode(cachedData);
             return decoded.map((e) => Order.fromJson(e)).toList();
           } catch (_) {}
         }
         return [];
      },
      right: (orders) {
        prefs.setString(cacheKey, jsonEncode(orders.map((o) => o.toJson()).toList()));
        return orders;
      },
    );
  }

  yield await fetch();
  yield* Stream.periodic(AppConstants.pollingInterval).asyncMap((_) => fetch());
});

// جلب طلبات العميل برقم الهاتف
final clientOrdersProvider = FutureProvider.family<List<Order>, String>((ref, phone) {
  return ref.watch(ordersRepositoryProvider).getByPhone(phone);
});

final ordersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(ordersRepositoryProvider).getAll();
});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? [];
  final techs = ref.watch(techsStreamProvider).valueOrNull ?? [];

  final revenue = orders
      .where((o) => o.status == OrderStatus.completed && o.finalPrice != null)
      .fold(0, (sum, o) => sum + (o.finalPrice ?? 0));

  return DashboardStats(
    totalOrders: orders.length,
    pendingOrders: orders.where((o) =>
      o.status == OrderStatus.pending || o.status == OrderStatus.assigned
    ).length,
    activeOrders: orders.where((o) =>
      o.status == OrderStatus.onTheWay || o.status == OrderStatus.started
    ).length,
    completedOrders: orders.where((o) => o.status == OrderStatus.completed).length,
    cancelledOrders: orders.where((o) => o.status == OrderStatus.cancelled).length,
    totalRevenue: revenue,
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
    'active': stats.activeOrders,
    'completed': stats.completedOrders,
    'revenue': stats.totalRevenue,
    'platformRevenue': stats.completedOrders * AppConstants.platformFee,
    'techTotal': stats.totalTechs,
    'techAvailable': stats.availableTechs,
    'techPending': stats.pendingTechs,
  };
});
