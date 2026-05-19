import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_actions_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/techs_provider.dart';
import '../widgets/order_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/models/order.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _showAssignTechSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final availableTechs = ref.read(availableTechsProvider(order.service));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تعيين فني للطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (availableTechs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'لا توجد فنيين متاحين متطابقين مع نوع الخدمة حالياً.',
                  ),
                )
              else
                ...availableTechs.map((tech) {
                  return ListTile(
                    title: Text(tech.name),
                    subtitle: Text(
                      '${tech.spec.label} • ${tech.area ?? 'الكل'}',
                    ),
                    trailing: Text('${tech.visitPrice} ج.م'),
                    onTap: () async {
                      final result = await ref
                          .read(adminActionsProvider)
                          .assignTech(order, tech);
                      if (!context.mounted) return;
                      result.when(
                        left: (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(failure.message)),
                          );
                        },
                        right: (_) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تعيين الفني بنجاح'),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showStatusSheet(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final selectedStatus = await showModalBottomSheet<OrderStatus>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) {
            return ListTile(
              title: Text(status.label),
              subtitle: status == order.status
                  ? const Text('الحالة الحالية')
                  : null,
              onTap: () {
                Navigator.of(context).pop(status);
              },
            );
          }).toList(),
        );
      },
    );

    if (selectedStatus == null || selectedStatus == order.status) return;

    final result = await ref
        .read(adminActionsProvider)
        .updateOrderStatus(order, selectedStatus);
    result.when(
      left: (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      right: (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الطلب')));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الطلبات')),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('لا توجد طلبات حالياً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: 'حدث خطأ أثناء تحميل الطلبات',
          onRetry: () => ref.refresh(ordersStreamProvider),
        ),
      ),
    );
  }
}
