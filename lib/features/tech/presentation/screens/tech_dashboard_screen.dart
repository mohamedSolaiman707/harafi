import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/notification_icon.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/models/order.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechDashboardScreen extends ConsumerStatefulWidget {
  const TechDashboardScreen({super.key});

  @override
  ConsumerState<TechDashboardScreen> createState() => _TechDashboardScreenState();
}

class _TechDashboardScreenState extends ConsumerState<TechDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTechAsync = ref.watch(currentTechnicianProvider);

    return currentTechAsync.when(
      data: (tech) {
        if (tech == null) return const _NewTechOnboarding();
        if (tech.status == TechStatus.pending) return _PendingApprovalScreen(tech: tech);

        final ordersAsync = ref.watch(techOrdersStreamProvider(tech.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('لوحة التحكم'),
            actions: [
              const NotificationIcon(),
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => context.push('/tech/profile'),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.gold,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'المهام الحالية'),
                Tab(text: 'سجل المهام'),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentTechnicianProvider);
              ref.invalidate(techOrdersStreamProvider(tech.id));
            },
            child: ordersAsync.when(
              data: (orders) => TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveOrders(orders, tech),
                  _buildHistoryOrders(orders),
                ],
              ),
              loading: () => const LoadingWidget(),
              error: (err, stack) => AppErrorWidget(
                message: 'خطأ في تحميل المهام',
                error: err,
                onRetry: () => ref.invalidate(techOrdersStreamProvider(tech.id)),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (err, stack) => Scaffold(
        body: AppErrorWidget(
          message: 'خطأ في تحميل البيانات',
          error: err,
          onRetry: () => ref.invalidate(currentTechnicianProvider),
        ),
      ),
    );
  }

  Widget _buildActiveOrders(List<Order> orders, Technician tech) {
    final activeOrders = orders.where((o) => 
      o.status != OrderStatus.completed && o.status != OrderStatus.cancelled
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _TechStatusCard(tech: tech),
        const SizedBox(height: AppSpacing.md),
        _buildFinancialSummary(tech),
        const SizedBox(height: AppSpacing.xxl),
        Text('مهام قيد التنفيذ (${activeOrders.length})', style: AppTextStyles.headlineMed),
        const SizedBox(height: AppSpacing.md),
        if (activeOrders.isEmpty)
          _buildEmptyState('لا توجد مهام حالية', Icons.task_alt)
        else
          ...activeOrders.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _TechOrderCard(order: order),
          )),
      ],
    );
  }

  Widget _buildHistoryOrders(List<Order> orders) {
    final historyOrders = orders.where((o) => 
      o.status == OrderStatus.completed || o.status == OrderStatus.cancelled
    ).toList();

    if (historyOrders.isEmpty) {
      return _buildEmptyState('سجل المهام فارغ', Icons.history);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: historyOrders.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _HistoryOrderCard(order: historyOrders[index]),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Technician tech) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppCard(
                color: AppColors.success.withValues(alpha: 0.05),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: AppColors.success, size: 24),
                    const SizedBox(height: 8),
                    Text('${tech.totalEarnings} ج.م', style: AppTextStyles.headlineMed.copyWith(color: AppColors.success)),
                    Text('إجمالي الأرباح', style: AppTextStyles.labelMed),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppCard(
              color: tech.rankColor.withValues(alpha: 0.1),
              child: Column(
                children: [
                  Icon(tech.rankIcon, color: tech.rankColor, size: 24),
                  const SizedBox(height: 8),
                  Text(tech.rank, style: AppTextStyles.titleMed.copyWith(color: tech.rankColor)),
                  Text('مستواك الحالي', style: AppTextStyles.labelMed),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.gold.withValues(alpha: 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'تقييمك العام: ${tech.rating.toStringAsFixed(1)} / 5',
                style: AppTextStyles.titleMed.copyWith(color: AppColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  final Order order;
  const _HistoryOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.status == OrderStatus.completed;

    return AppCard(
      color: AppColors.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.trackingCode, style: AppTextStyles.labelLarge),
              Text(
                isCompleted ? 'مكتمل ✅' : 'ملغي ❌',
                style: TextStyle(
                  color: isCompleted ? AppColors.success : AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.clientName, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'التاريخ: ${order.createdAt.toString().split(' ')[0]}',
            style: AppTextStyles.labelMed,
          ),
          if (isCompleted && order.finalPrice != null) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ المحصل:', style: AppTextStyles.bodyMed),
                Text('${order.finalPrice} ج.م', style: AppTextStyles.titleMed.copyWith(color: AppColors.success)),
              ],
            ),
            if (order.rating != null)
              Row(
                children: [
                  Text('تقييم العميل: ', style: AppTextStyles.bodyMed),
                  ...List.generate(5, (i) => Icon(
                    i < order.rating! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.gold,
                  )),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _NewTechOnboarding extends StatelessWidget {
  const _NewTechOnboarding();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_outlined, size: 80, color: AppColors.gold),
              const SizedBox(height: 24),
              Text('أهلاً بك في حرافي', style: AppTextStyles.displayMedium),
              const SizedBox(height: 16),
              const Text(
                'لقد تم تفعيل رقم هاتفك بنجاح. الخطوة الأخيرة هي إكمال ملفك الفني لنتمكن من إرسال العملاء إليك.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'إكمال بيانات الملف الفني',
                onTap: () => context.push('/tech/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalScreen extends StatelessWidget {
  final Technician tech;
  const _PendingApprovalScreen({required this.tech});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty_rounded, size: 80, color: AppColors.gold),
              const SizedBox(height: 24),
              Text('حسابك قيد المراجعة', style: AppTextStyles.displayMedium),
              const SizedBox(height: 16),
              const Text(
                'شكراً لانضمامك. يقوم فريق حرافي حالياً بمراجعة بياناتك لضمان الجودة. يمكنك الضغط على الزر أدناه لتأكيد هويتك عبر واتساب وتسريع العملية.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'تفعيل الحساب عبر واتساب',
                variant: ButtonVariant.whatsapp,
                icon: Icons.chat,
                onTap: () {
                  final message = 'السلام عليكم، أنا الفني ${tech.name} (تخصص ${tech.spec.label}) أريد تفعيل حسابي على منصة حرافي برقم ${tech.phone}';
                  final uri = WhatsAppUtils.buildUri('201014250577', message); 
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'العودة للرئيسية',
                variant: ButtonVariant.ghost,
                onTap: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechStatusCard extends ConsumerWidget {
  final Technician tech;
  const _TechStatusCard({required this.tech});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = tech.status == TechStatus.available;

    return AppCard(
      color: isAvailable ? AppColors.gold.withValues(alpha: 0.05) : AppColors.surface2,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isAvailable ? AppColors.success.withValues(alpha: 0.1) : AppColors.textMuted.withValues(alpha: 0.1),
            child: Icon(
              isAvailable ? Icons.check_circle : Icons.pause_circle_filled,
              color: isAvailable ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('يا بشمهندس ${tech.name}', style: AppTextStyles.titleLarge),
                Text(
                  isAvailable ? 'أنت متاح لاستقبال الطلبات' : 'أنت في وضع الاستراحة',
                  style: AppTextStyles.bodyMed.copyWith(color: isAvailable ? AppColors.success : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            activeColor: AppColors.success,
            onChanged: (val) async {
              await ref.read(techsRepositoryProvider).updateTechStatus(
                tech.id,
                val ? TechStatus.available : TechStatus.onLeave,
              );
              ref.invalidate(currentTechnicianProvider);
              ref.invalidate(techsStreamProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _TechOrderCard extends StatelessWidget {
  final Order order;
  const _TechOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/tech/order/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.trackingCode, style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(order.clientName, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(order.area ?? 'كفر الزيات', style: AppTextStyles.bodyMed),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'عرض التفاصيل',
                  size: ButtonSize.sm,
                  onTap: () => context.push('/tech/order/${order.id}'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _ActionButton(
                icon: Icons.phone,
                color: AppColors.success,
                onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                color: const Color(0xFF25D366),
                onTap: () {
                  final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم يا ${order.clientName}، أنا الفني من حرافي وبخصوص طلبك...');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(status.label, style: AppTextStyles.labelMed),
    );
  }
}
