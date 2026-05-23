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
        title: const Text('إدارة الطلبات والعمليات'),
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
                emptyMessage: 'لا توجد طلبات قيد التنفيذ',
              ),
              _OrdersList(
                orders: orders.where((o) => o.status == OrderStatus.completed).toList(),
                emptyMessage: 'سجل الطلبات المكتملة فارغ',
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
          message: 'فشل الاتصال بقاعدة البيانات',
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
            const Icon(Icons.assignment_late_outlined, size: 64, color: AppColors.textMuted),
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

  Future<void> _showAssignTechSheet(BuildContext context, WidgetRef ref, Order order) async {
    final availableTechs = ref.read(availableTechsProvider(order.service));
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تعيين فني لـ ${order.clientName}', style: AppTextStyles.headlineMed),
            Text('الخدمة: ${order.service.label}', style: AppTextStyles.bodyMed.copyWith(color: AppColors.gold)),
            const SizedBox(height: 24),
            if (availableTechs.isEmpty)
              const Center(child: Text('عذراً، لا يوجد فنيين متاحين حالياً لهذا التخصص'))
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableTechs.length,
                  itemBuilder: (context, index) {
                    final tech = availableTechs[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha: 0.1), child: Text(tech.spec.icon)),
                      title: Text(tech.name),
                      subtitle: Text('التقييم: ${tech.rating} ⭐ • السعر: ${tech.visitPrice} ج.م'),
                      trailing: const Icon(Icons.chevron_left, color: AppColors.gold),
                      onTap: () async {
                        final result = await ref.read(adminActionsProvider).assignTech(order, tech);
                        if (context.mounted) {
                          result.when(
                            left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
                            right: (_) => Navigator.pop(context),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusSheet(BuildContext context, WidgetRef ref, Order order) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined, color: Colors.amber),
              title: const Text('الفني في الطريق'),
              onTap: () {
                ref.read(adminActionsProvider).updateOrderStatus(order, OrderStatus.onTheWay);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
              title: const Text('إلغاء الطلب'),
              onTap: () {
                ref.read(adminActionsProvider).updateOrderStatus(order, OrderStatus.cancelled);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
