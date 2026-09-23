import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/providers/notification_provider.dart';
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
                if (tech.status == TechStatus.pending)
                  _buildPendingApprovalBanner(tech),

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
                  isActive
                      ? (tech.status == TechStatus.pending
                          ? 'حسابك قيد المراجعة والتدقيق حالياً، وسيتم تفعيل إمكانية استقبال الطلبات فور اعتماد أوراقك من الإدارة ⏳'
                          : 'أنت جاهز لاستقبال الطلبات، سيصلك تنبيه فور طلب عميل بالقرب منك 🟢')
                      : 'سجل المهام فارغ',
                  isActive ? Icons.radar_rounded : Icons.history,
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width > 800 ? 2 : 1,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: isActive ? 225 : 215,
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

  Widget _buildPendingApprovalBanner(Technician tech) {
    final hasNote = tech.adminNote != null && tech.adminNote!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: hasNote
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: hasNote
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.gold.withValues(alpha: 0.4),
          width: hasNote ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasNote ? AppColors.error : AppColors.gold).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasNote ? Icons.info_outline_rounded : Icons.hourglass_top_rounded,
                  color: hasNote ? AppColors.error : AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasNote
                        ? 'ملاحظة من الإدارة – يرجى الاطلاع ⚠️'
                        : 'حسابك غير مفعل بعد (قيد المراجعة) ⏳',
                      style: AppTextStyles.titleMed.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasNote ? AppColors.error : AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasNote
                        ? tech.adminNote!
                        : 'يقوم فريق حرفي بمراجعة بياناتك ومستنداتك لضمان الجودة والأمان. يرجى الانتظار حتى يتم الاعتماد وسيصلك إشعار فور التفعيل.',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasNote
                            ? AppColors.error.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                        fontWeight: hasNote ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  final message = hasNote
                    ? 'السلام عليكم، أنا الفني ${tech.name} أريد الرد على ملاحظة الإدارة برقم ${tech.phone}'
                    : 'السلام عليكم، أنا الفني ${tech.name} أريد الاستفسار عن حالة تفعيل حسابي برقم ${tech.phone}';
                  launchUrl(
                    WhatsAppUtils.buildUri('201014250577', message),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        hasNote
                          ? 'الرد على الإدارة 💬'
                          : 'تواصل مع الإدارة للتفعيل السريع 💬',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
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
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMed.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Technician tech, double width) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStatItem(
            label: 'المحفظة',
            value: '${tech.walletBalance} ج.م',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.gold,
            actionLabel: 'شحن ⚡',
            onAction: () => context.push('/tech/wallet'),
          ),
          Container(height: 36, width: 1, color: AppColors.borderSubtle),
          _QuickStatItem(
            label: 'الأرباح',
            value: '${tech.totalEarnings} ج.م',
            icon: Icons.monetization_on_rounded,
            iconColor: AppColors.success,
          ),
          Container(height: 36, width: 1, color: AppColors.borderSubtle),
          _QuickStatItem(
            label: 'التقييم',
            value: '${tech.rating.toStringAsFixed(1)} ★',
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
          ),
        ],
      ),
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _QuickStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelMed.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTextStyles.titleMed.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
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



class _TechStatusCard extends ConsumerWidget {
  final Technician tech;
  const _TechStatusCard({required this.tech});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = tech.status == TechStatus.pending;
    final isAvailable = tech.status == TechStatus.available;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPending
              ? [AppColors.gold.withValues(alpha: 0.15), AppColors.surface1]
              : (isAvailable
                  ? [AppColors.success.withValues(alpha: 0.15), AppColors.surface1]
                  : [AppColors.surface2, AppColors.surface1]),
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: isPending
              ? AppColors.gold.withValues(alpha: 0.4)
              : (isAvailable
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.borderSubtle),
          width: 1.5,
        ),
        boxShadow: isAvailable
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : (isAvailable
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.surface2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : (isAvailable
                      ? Icons.sensors_rounded
                      : Icons.pause_circle_filled_rounded),
              color: isPending ? AppColors.gold : (isAvailable ? AppColors.success : AppColors.textMuted),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
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
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tech.rankColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: tech.rankColor.withValues(alpha: 0.3),
                        ),
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
                const SizedBox(height: 3),
                Text(
                  isPending
                      ? 'حسابك غير مفعل بعد (قيد المراجعة) ⏳'
                      : (isAvailable
                          ? 'أنت متاح الآن لاستقبال طلبات العملاء 🟢'
                          : 'أنت في وضع الاستراحة 🔴'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isPending ? AppColors.gold : (isAvailable ? AppColors.success : AppColors.textMuted),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.95,
            child: Switch(
              value: isAvailable,
              activeThumbColor: AppColors.success,
              activeTrackColor: AppColors.success.withValues(alpha: 0.3),
              onChanged: isPending
                  ? (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.gold,
                          content: Text(
                            'حسابك قيد المراجعة حالياً، وسيتم تفعيل إمكانية استقبال الطلبات فور موافقة الإدارة 🛡️',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                      );
                    }
                  : (val) async {
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
                              backgroundColor: val ? AppColors.success : AppColors.surface2,
                              content: Text(
                                val
                                    ? 'أنت متاح الآن لاستقبال الطلبات 🚀'
                                    : 'أنت الآن في وضع الاستراحة 😴',
                                style: const TextStyle(fontWeight: FontWeight.bold),
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

class _TechOrderCard extends ConsumerWidget {
  final Order order;
  const _TechOrderCard({required this.order});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScheduled = order.isScheduled;
    final dateFormatted = order.scheduledDate != null
        ? intl.DateFormat('d MMM yyyy').format(order.scheduledDate!)
        : '';

    final unreadCount = ref.watch(unreadMsgCountsProvider)[order.id] ?? 0;

    return AppCard(
      color: AppColors.surface1,
      padding: const EdgeInsets.all(14),
      onTap: () {
        ref.read(notificationProvider.notifier).clearUnreadForOrder(order.id);
        context.push('/tech/order/${order.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),

          // شارة الموعد المجدول أو الطلب الفوري
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isScheduled
                  ? AppColors.gold.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
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
                      : Icons.bolt_rounded,
                  size: 14,
                  color: isScheduled ? AppColors.gold : AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  isScheduled
                      ? 'مجدول: $dateFormatted ${order.preferredTimeSlot != null ? "• ${order.preferredTimeSlot}" : ""}'
                      : 'طلب فوري مباشر ⚡',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isScheduled ? AppColors.gold : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    order.service.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.clientName,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          order.area ?? 'كفر الزيات',
                          style: AppTextStyles.bodyMed.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // أزرار الإجراءات السريعة والمباشرة للفني
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: unreadCount > 0 ? 'تفاصيل الطلب ($unreadCount جديد) 💬' : 'تفاصيل الطلب ⚡',
                  size: ButtonSize.sm,
                  onTap: () {
                    ref.read(notificationProvider.notifier).clearUnreadForOrder(order.id);
                    context.push('/tech/order/${order.id}');
                  },
                ),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                icon: Icons.phone_forwarded_rounded,
                color: AppColors.success,
                tooltip: 'اتصال هاتفياً بالعميل',
                onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
              ),
              const SizedBox(width: 4),
              _QuickActionButton(
                icon: Icons.map_rounded,
                color: AppColors.gold,
                tooltip: 'فتح الموقع في الخريطة',
                onTap: () => MapUtils.openMapWithAddress(order.area ?? 'كفر الزيات'),
              ),
              if (order.clientPhone.isNotEmpty) ...[
                const SizedBox(width: 4),
                _QuickActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.info,
                  tooltip: 'مراسلة العميل عبر واتساب',
                  onTap: () {
                    final message = 'السلام عليكم أ/ ${order.clientName}، مع حضرتك الفني لمتابعة طلب رقم ${order.trackingCode}';
                    launchUrl(
                      WhatsAppUtils.buildUri(order.clientPhone, message),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelMed.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

