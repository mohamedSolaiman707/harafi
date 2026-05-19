import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/models/order.dart';
import '../../domain/enums/order_status.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return SupabaseOrdersRepository(Supabase.instance.client);
});

final ordersStreamProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(ordersRepositoryProvider).watchAll();
});

final statsProvider = Provider((ref) {
  final orders = ref.watch(ordersStreamProvider).valueOrNull ?? [];
  return {
    'total': orders.length,
    'pending': orders.where((o) => o.status == OrderStatus.pending).length,
    'completed': orders.where((o) => o.status == OrderStatus.completed).length,
  };
});
