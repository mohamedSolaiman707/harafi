import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return currentTechAsync.when(
      data: (tech) {
        if (tech == null) return const _NewTechOnboarding();
        if (tech.status == TechStatus.pending) return _PendingApprovalScreen(tech: tech);

        final ordersAsync = ref.watch(techOrdersStreamProvider(tech.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('لوحة تحكم الفني'),
            centerTitle: !isDesktop,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: AppColors.gold),
                tooltip: 'دليل الانطلاق والشرح',
                onPressed: () => OnboardingGuideSheet.show(
                  context,
                  isTechnician: true,
                  userName: tech.name,
                  userArea: tech.area,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold),
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

  Widget _buildOrderList(List<Order> orders, Technician tech, {required bool isActive}) {
    final filteredOrders = isActive 
        ? orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).toList()
        : orders.where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled).toList();

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
                  Container(
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
                            'رصيدك غير كافٍ (${tech.walletBalance}ج)، يرجى شحن المحفظة بـ ${AppConstants.platformFee}ج أو أكثر لاستقبال الطلبات الجديدة.',
                            style: AppTextStyles.bodyMed.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/tech/wallet'),
                          child: const Text('شحن 💳', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                if (tech.totalJobs == 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration_rounded, color: AppColors.gold, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رصيد ترحيبي 100 ج.م مفعل بمحفظتك 🎉',
                                style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'جاهز لاستقبال أولى مشاويرك فوراً دون تكاليف',
                                style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => OnboardingGuideSheet.show(
                            context,
                            isTechnician: true,
                            userName: tech.name,
                            userArea: tech.area,
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.gold),
                          label: const Text('الدليل 📖', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                _TechStatusCard(tech: tech),
                const SizedBox(height: AppSpacing.lg),
                _buildFinancialSummary(tech, width),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  isActive ? 'المهام المطلوبة منك (${filteredOrders.length})' : 'سجل المهام المنتهية',
                  style: AppTextStyles.headlineMed,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              
              if (filteredOrders.isEmpty)
                _buildEmptyState(
                  isActive ? 'لا توجد مهام حالية' : 'سجل المهام فارغ', 
                  isActive ? Icons.task_alt : Icons.history
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: width > 800 ? 2 : 1,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: isActive ? 210 : 180,
                  ),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) => isActive 
                      ? _TechOrderCard(order: filteredOrders[index])
                      : _HistoryOrderCard(order: filteredOrders[index]),
                ),
            ],
          ),
        ),
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
          Icon(icon, size: 80, color: AppColors.textMuted.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Technician tech, double width) {
    final crossAxisCount = width > 800 ? 4 : 2;
    return Column(
      children: [
        // كروت الإحصائيات الأربعة بتصميم عصري وخفيف
        GridView.count(
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
        ),
        const SizedBox(height: AppSpacing.md),

        // شريط التقدم نحو الرتبة التالية (تصميم مدمج وأنيق)
        if (tech.jobsToNextRank > 0)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(tech.rankEmoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          ' المستوي التالي: ${tech.nextRankTitle}',
                          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      'متبقي ${tech.jobsToNextRank} طلب',
                      style: TextStyle(color: tech.rankColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: tech.nextRankProgress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(tech.rankColor),
                  ),
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
      color: AppColors.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.trackingCode, style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isCompleted ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCompleted ? 'مكتمل' : 'ملغي',
                  style: TextStyle(color: isCompleted ? AppColors.success : AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.clientName, style: AppTextStyles.titleLarge),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.createdAt.toString().split(' ')[0], style: AppTextStyles.labelMed),
              if (isCompleted && order.finalPrice != null)
                Text('${order.finalPrice} ج.م', style: AppTextStyles.titleMed.copyWith(color: AppColors.success)),
            ],
          ),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_outlined, size: 80, color: AppColors.gold),
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
          IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))
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
                const Icon(Icons.hourglass_empty_rounded, size: 80, color: AppColors.gold),
                const SizedBox(height: 24),
                Text('حسابك قيد المراجعة', style: AppTextStyles.displayMedium),
                const SizedBox(height: 16),
                const Text(
                  'شكراً لانضمامك. يقوم فريق حرفي حالياً بمراجعة بياناتك لضمان الجودة. يمكنك الضغط على الزر أدناه لتأكيد هويتك عبر واتساب وتسريع العملية.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'تفعيل الحساب عبر واتساب',
                  variant: ButtonVariant.whatsapp,
                  icon: Icons.chat,
                  onTap: () {
                    final message = 'السلام عليكم، أنا الفني ${tech.name} (تخصص ${tech.spec.label}) أريد تفعيل حسابي على منصة حرفي برقم ${tech.phone}';
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
          color: isAvailable ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isAvailable ? AppColors.success.withValues(alpha: 0.15) : AppColors.surface2,
            child: Icon(
              isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
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
                        style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tech.rankColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tech.rank,
                        style: TextStyle(color: tech.rankColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable ? 'أنت متاح لاستقبال الطلبات 🟢' : 'في وضع الاستراحة 🔴',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAvailable ? AppColors.success : AppColors.textMuted,
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
                await ref.read(techsRepositoryProvider).updateTechStatus(
                  tech.id,
                  val ? TechStatus.available : TechStatus.onLeave,
                );
                ref.invalidate(currentTechnicianProvider);
                ref.invalidate(techsStreamProvider);
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
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
          Text(
            value,
            style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
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
          const Spacer(),
          const Divider(),
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
                icon: Icons.map_outlined,
                color: AppColors.gold,
                onTap: () => MapUtils.openMapWithAddress(order.area ?? 'كفر الزيات'),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                  final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم يا ${order.clientName}، أنا الفني من حرفي وبخصوص طلبك...');
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
