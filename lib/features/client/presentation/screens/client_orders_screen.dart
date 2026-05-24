import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/orders_provider.dart';

class ClientOrdersScreen extends ConsumerStatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  ConsumerState<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends ConsumerState<ClientOrdersScreen> {
  final _phoneController = TextEditingController();
  String? _submittedPhone;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _search() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _submittedPhone = _phoneController.text.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل طلباتي'),
        centerTitle: !isDesktop,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const Icon(Icons.history_rounded, color: AppColors.gold, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'أدخل رقم هاتفك لعرض جميع طلباتك السابقة والحالية وتتبعها',
                            textAlign: TextAlign.center,
                            style: TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppTextField(
                            label: 'رقم الهاتف',
                            hint: '01xxxxxxxxx',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_android,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'عرض سجل الطلبات',
                            onTap: _search,
                            icon: Icons.search_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                if (_submittedPhone != null)
                  ref.watch(clientOrdersProvider(_submittedPhone!)).when(
                        data: (orders) => _OrdersList(orders: orders),
                        loading: () => const LoadingWidget(),
                        error: (e, s) => AppErrorWidget(
                          message: 'فشل جلب الطلبات',
                          error: e,
                          onRetry: _search,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.assignment_late_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('لم نجد أي طلبات مسجلة لهذا الرقم حتى الآن'),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('قائمة الطلبات (${orders.length})', style: AppTextStyles.headlineMed),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: 220,
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _OrderCard(order: orders[index]);
          },
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = order.status == OrderStatus.completed;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: order.trackingCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ كود التتبع')));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Text(
                        order.trackingCode,
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold, letterSpacing: 1, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 12, color: AppColors.gold),
                    ],
                  ),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(order.service.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.service.label, style: AppTextStyles.titleLarge),
                    Text('بتاريخ: ${order.createdAt.toString().split(' ')[0]}', style: AppTextStyles.labelMed),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'تتبع الآن',
                  size: ButtonSize.sm,
                  variant: ButtonVariant.ghost,
                  onTap: () => context.push('/track/${order.trackingCode}'),
                ),
              ),
              const SizedBox(width: 12),
              if (isCompleted)
                Expanded(
                  child: AppButton(
                    label: 'طلب جديد',
                    size: ButtonSize.sm,
                    icon: Icons.add_task,
                    onTap: () => context.push('/request', extra: {'service': order.service, 'techId': order.techId}),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case OrderStatus.pending: color = AppColors.gold; break;
      case OrderStatus.assigned: color = AppColors.info; break;
      case OrderStatus.onTheWay: color = Colors.orange; break;
      case OrderStatus.started: color = Colors.blue; break;
      case OrderStatus.completed: color = AppColors.success; break;
      case OrderStatus.cancelled: color = AppColors.error; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
