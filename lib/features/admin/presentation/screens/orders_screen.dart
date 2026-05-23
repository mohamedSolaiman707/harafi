import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_actions_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/techs_provider.dart';
import '../widgets/order_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/models/order.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'جديدة'),
            Tab(text: 'نشطة'),
            Tab(text: 'مكتملة'),
            Tab(text: 'ملغاة'),
          ],
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          return TabBarView(
            controller: _tabController,
            children: [
              _OrdersList(
                orders: orders.where((o) => o.status == OrderStatus.pending).toList(),
                emptyMessage: 'لا توجد طلبات جديدة حالياً',
              ),
              _OrdersList(
                orders: orders.where((o) => 
                  [OrderStatus.assigned, OrderStatus.onTheWay, OrderStatus.started].contains(o.status)
                ).toList(),
                emptyMessage: 'لا توجد طلبات جاري تنفيذها',
              ),
              _OrdersList(
                orders: orders.where((o) => o.status == OrderStatus.completed).toList(),
                emptyMessage: 'لم تكتمل أي طلبات بعد',
              ),
              _OrdersList(
                orders: orders.where((o) => o.status == OrderStatus.cancelled).toList(),
                emptyMessage: 'لا توجد طلبات ملغاة',
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: 'خطأ في تحميل البيانات',
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  final List<Order> orders;
  final String emptyMessage;

  const _OrdersList({required this.orders, required this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(emptyMessage, style: AppTextStyles.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onUpdateStatus: () => _showStatusSheet(context, ref, order),
          onAssignTech: () => _showAssignTechSheet(context, ref, order),
        );
      },
    );
  }

  // الدوال المساعدة لتعيين الفني وتحديث الحالة (نفس المنطق المظبوط الذي تم شرحه سابقاً)
  Future<void> _showAssignTechSheet(BuildContext context, WidgetRef ref, Order order) async {
     // ... منطق تعيين الفني ...
  }

  Future<void> _showStatusSheet(BuildContext context, WidgetRef ref, Order order) async {
     // ... منطق تحديث الحالة ...
  }
}
