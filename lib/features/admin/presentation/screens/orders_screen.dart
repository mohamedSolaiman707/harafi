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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات والعمليات'),
        centerTitle: !isDesktop,
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
          error: err,
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

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1400 ? 3 : (width > 900 ? 2 : 1);
    final sidePadding = width > 1200 ? width * 0.05 : AppSpacing.lg;

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: AppSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: 430, // زيادة الطول الكافي لمنع الـ Overflow على كافة الأجهزة
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onUpdateStatus: () => _showAdminActionSheet(context, ref, order),
          onAssignTech: () => _showAssignTechSheet(context, ref, order),
        );
      },
    );
  }

  Future<void> _showAssignTechSheet(BuildContext context, WidgetRef ref, Order order) async {
    final availableTechs = ref.read(availableTechsProvider(order.service));
    final width = MediaQuery.of(context).size.width;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 600 : width), // عرض محدد للديسكتوب
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
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('عذراً، لا يوجد فنيين متاحين حالياً لهذا التخصص'),
              ))
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
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

  Future<void> _showAdminActionSheet(BuildContext context, WidgetRef ref, Order order) async {
    final width = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 500 : width),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('إجراءات إدارية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            if (order.status != OrderStatus.cancelled && order.status != OrderStatus.completed)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
                title: const Text('إلغاء هذا الطلب نهائياً'),
                onTap: () {
                  ref.read(adminActionsProvider).updateOrderStatus(
                    order, 
                    OrderStatus.cancelled,
                    logMessage: 'تم إلغاء الطلب بمعرفة الإدارة',
                  );
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.grey),
              title: const Text('حذف من السجلات'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حذف الطلب'),
                    content: const Text('هل أنت متأكد من حذف الطلب نهائياً؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(ordersRepositoryProvider).deleteOrder(order.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
