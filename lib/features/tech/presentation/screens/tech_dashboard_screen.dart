import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/notification_icon.dart';
import '../../../../shared/widgets/onboarding_guide_sheet.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/models/order.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/map_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechDashboardScreen extends ConsumerStatefulWidget {
  const TechDashboardScreen({super.key});

  @override
  ConsumerState<TechDashboardScreen> createState() =>
      _TechDashboardScreenState();
}

class _TechDashboardScreenState extends ConsumerState<TechDashboardScreen>
    with SingleTickerProviderStateMixin {
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return currentTechAsync.when(
      data: (tech) {
        if (tech == null) return const _NewTechOnboarding();
        if (tech.status == TechStatus.pending)
          return _PendingApprovalScreen(tech: tech);

        final ordersAsync = ref.watch(techOrdersStreamProvider(tech.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('لوحة تحكم الفني'),
            centerTitle: !isDesktop,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.gold,
                ),
                tooltip: 'دليل الانطلاق والشرح',
                onPressed: () => OnboardingGuideSheet.show(
                  context,
                  isTechnician: true,
                  userName: tech.name,
                  userArea: tech.area,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.gold,
                ),
                tooltip: 'محفظتي',
                onPressed: () => context.push('/tech/wallet'),
              ),
              const NotificationIcon(),
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => context.push('/tech/profile'),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.gold,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.textSecondary,
                    tabs: const [
                      Tab(text: 'المهام النشطة'),
                      Tab(text: 'سجل المهام'),
                    ],
                  ),
                ),
              ),
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
                  _buildOrderList(orders, tech, isActive: true),
                  _buildOrderList(orders, tech, isActive: false),
                ],
              ),
              loading: () => const LoadingWidget(),
              error: (err, stack) => AppErrorWidget(
                message: AppErrorHandler.translate(err),
                error: err,
                onRetry: () =>
                    ref.invalidate(techOrdersStreamProvider(tech.id)),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (err, stack) => Scaffold(
        body: AppErrorWidget(
          message: AppErrorHandler.translate(err),
          error: err,
          onRetry: () => ref.invalidate(currentTechnicianProvider),
        ),
      ),
    );
  }

  Widget _buildOrderList(
    List<Order> orders,
    Technician tech, {
    required bool isActive,
  }) {
    final filteredOrders = isActive
        ? orders
              .where(
                (o) =>
                    o.status != OrderStatus.completed &&
                    o.status != OrderStatus.cancelled,
              )
              .toList()
        : orders
              .where(
                (o) =>
                    o.status == OrderStatus.completed ||
                    o.status == OrderStatus.cancelled,
              )
              .toList();

    final width = MediaQuery.of(context).size.width;
    const double maxContentWidth = 1000;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isActive) ...[
                if (tech.walletBalance < AppConstants.platformFee)
                  _buildBalanceWarning(tech.walletBalance),

                _TechStatusCard(tech: tech),
                const SizedBox(height: AppSpacing.lg),
                _buildFinancialSummary(tech, width),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'المهام المطلوبة منك (${filteredOrders.length})',
                  style: AppTextStyles.headlineMed,
                ),
                const SizedBox(height: AppSpacing.md),
              ] else ...[
                _buildHistoryDashboard(filteredOrders),
                const SizedBox(height: AppSpacing.xl),
                Text('التفاصيل الزمنية', style: AppTextStyles.headlineMed),
                const SizedBox(height: AppSpacing.md),
              ],

              if (filteredOrders.isEmpty)
                _buildEmptyState(
                  isActive ? 'لا توجد مهام حالية' : 'سجل المهام فارغ',
                  isActive ? Icons.task_alt : Icons.history,
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width > 800 ? 2 : 1,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: isActive ? 210 : 215,
                  ),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) => isActive
                      ? _TechOrderCard(order: filteredOrders[index])
                      : _HistoryOrderCard(order: filteredOrders[index]),
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceWarning(int balance) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'رصيدك غير كافٍ ($balance ج.م)، يرجى شحن المحفظة بـ ${AppConstants.platformFee}ج أو أكثر لاستقبال الطلبات.',
              style: AppTextStyles.bodyMed.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/tech/wallet'),
            child: const Text(
              'شحن 💳',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDashboard(List<Order> historyOrders) {
    final completed = historyOrders
        .where((o) => o.status == OrderStatus.completed)
        .toList();
    final totalRevenue = completed.fold(
      0,
      (sum, o) => sum + (o.finalPrice ?? 0),
    );
    final successRate = historyOrders.isEmpty
        ? 0
        : (completed.length / historyOrders.length * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HistoryStatTile(
            label: 'صافي الأرباح',
            value: '$totalRevenue ج.م',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.success,
          ),
          _HistoryStatTile(
            label: 'مهام مكتملة',
            value: '${completed.length}',
            icon: Icons.task_alt_rounded,
            color: AppColors.info,
          ),
          _HistoryStatTile(
            label: 'نسبة النجاح',
            value: '$successRate%',
            icon: Icons.auto_graph_rounded,
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppColors.textMuted.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: AppColors.textMuted, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Technician tech, double width) {
    final crossAxisCount = width > 800 ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: width > 800 ? 2.2 : 1.5,
      children: [
        _StatTile(
          title: 'إجمالي الأرباح',
          value: '${tech.totalEarnings} ج.م',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: AppColors.success,
        ),
        _StatTile(
          title: 'رصيد المحفظة',
          value: '${tech.walletBalance} ج.م',
          icon: Icons.account_balance_rounded,
          iconColor: AppColors.gold,
          actionLabel: 'شحن ⚡',
          onAction: () => context.push('/tech/wallet'),
        ),
        _StatTile(
          title: 'تقييمك العام',
          value: '${tech.rating.toStringAsFixed(1)} ★',
          icon: Icons.star_rounded,
          iconColor: Colors.amber,
        ),
        _StatTile(
          title: 'العمليات الناجحة',
          value: '${tech.totalJobs} طلب',
          icon: Icons.task_alt_rounded,
          iconColor: AppColors.info,
        ),
      ],
    );
  }
}

class _HistoryStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _HistoryStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
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
    final bool hasWarranty = order.isWarrantyActive;
    final statusColor = isCompleted ? AppColors.success : AppColors.error;

    return AppCard(
      color: AppColors.surface1,
      onTap: () => context.push('/tech/order/${order.id}'),
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: statusColor.withOpacity(0.5), width: 4),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.trackingCode,
                          style: AppTextStyles.labelMed.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (hasWarranty) ...[
                        const SizedBox(width: 8),
                        _WarrantyBadge(days: order.warrantyRemainingDays),
                      ],
                    ],
                  ),
                  _HistoryStatusBadge(status: order.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        order.service.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          order.service.label,
                          style: AppTextStyles.labelMed.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted && order.rating != null)
                    _buildRatingDisplay(order.rating!),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface2.withOpacity(0.3),
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderSubtle.withOpacity(0.5),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.createdAt.toString().split(' ')[0],
                        style: AppTextStyles.labelMed.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (isCompleted && order.finalPrice != null)
                    Text(
                      '${order.finalPrice} ج.م',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else
                    const Text(
                      '---',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingDisplay(int rating) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            Text(
              ' $rating',
              style: AppTextStyles.titleMed.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          'التقييم',
          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _WarrantyBadge extends StatelessWidget {
  final int days;
  const _WarrantyBadge({required this.days});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 10,
            color: AppColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            'ضمان $days يوم',
            style: const TextStyle(
              color: AppColors.info,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _HistoryStatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isCompleted = status == OrderStatus.completed;
    final color = isCompleted ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_add_outlined,
                  size: 80,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 24),
                Text('أهلاً بك في حرفي', style: AppTextStyles.displayMedium),
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
          IconButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 80,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 24),
                Text('حسابك قيد المراجعة', style: AppTextStyles.displayMedium),
                const SizedBox(height: 16),
                const Text(
                  'شكراً لانضمامك. يقوم فريق حرفي حالياً بمراجعة بياناتك لضمان الجودة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'تفعيل عبر واتساب',
                  variant: ButtonVariant.whatsapp,
                  icon: Icons.chat,
                  onTap: () {
                    final message =
                        'السلام عليكم، أنا الفني ${tech.name} أريد تفعيل حسابي برقم ${tech.phone}';
                    launchUrl(
                      WhatsAppUtils.buildUri('201014250577', message),
                      mode: LaunchMode.externalApplication,
                    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isAvailable
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isAvailable
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.surface2,
            child: Icon(
              isAvailable
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_filled_rounded,
              color: isAvailable ? AppColors.success : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'يا بشمهندس ${tech.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMed.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tech.rankColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tech.rank,
                        style: TextStyle(
                          color: tech.rankColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable
                      ? 'أنت متاح لاستقبال الطلبات 🟢'
                      : 'في وضع الاستراحة 🔴',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAvailable
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isAvailable,
              activeThumbColor: AppColors.success,
              onChanged: (val) async {
                final result = await ref
                    .read(techsRepositoryProvider)
                    .updateTechStatus(
                      tech.id,
                      val ? TechStatus.available : TechStatus.onLeave,
                    );
                result.when(
                  left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                  right: (ut) {
                    ref.read(currentTechnicianProvider.notifier).updateTech(ut);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'أنت متاح الآن لاستقبال الطلبات 🚀'
                              : 'أنت الآن في وضع الاستراحة 😴',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              if (actionLabel != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
          ),
          Text(
            value,
            style: AppTextStyles.titleMed.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
    final isScheduled = order.isScheduled;
    final dateFormatted = order.scheduledDate != null
        ? intl.DateFormat('d MMM yyyy').format(order.scheduledDate!)
        : '';

    return AppCard(
      onTap: () => context.push('/tech/order/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.trackingCode,
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // شارة الموعد المجدول أو الطلب الفوري
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isScheduled
                  ? AppColors.gold.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isScheduled
                    ? AppColors.gold.withValues(alpha: 0.3)
                    : AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isScheduled
                      ? Icons.event_available_rounded
                      : Icons.flash_on_rounded,
                  size: 13,
                  color: isScheduled ? AppColors.gold : AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  isScheduled
                      ? 'مجدول: $dateFormatted ${order.preferredTimeSlot != null ? "• ${order.preferredTimeSlot}" : ""}'
                      : 'طلب فوري (الآن) ⚡',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isScheduled ? AppColors.gold : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          Text(order.clientName, style: AppTextStyles.titleLarge),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(order.area ?? 'كفر الزيات', style: AppTextStyles.bodyMed),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'عرض التفاصيل',
                  size: ButtonSize.sm,
                  onTap: () => context.push('/tech/order/${order.id}'),
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.map_outlined,
                color: AppColors.gold,
                onTap: () =>
                    MapUtils.openMapWithAddress(order.area ?? 'كفر الزيات'),
              ),
              _ActionButton(
                icon: Icons.phone,
                color: AppColors.success,
                onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
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
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
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
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(status.label, style: AppTextStyles.labelMed),
    );
  }
}
