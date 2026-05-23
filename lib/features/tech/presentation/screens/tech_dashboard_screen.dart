import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/models/order.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TechDashboardScreen extends ConsumerWidget {
  const TechDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTechAsync = ref.watch(currentTechnicianProvider);

    return currentTechAsync.when(
      data: (tech) {
        if (tech == null) return const _NewTechOnboarding();
        
        if (tech.status == TechStatus.pending) {
          return _PendingApprovalScreen(tech: tech);
        }

        final ordersAsync = ref.watch(techOrdersStreamProvider(tech.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('لوحة التحكم'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => context.push('/tech/profile'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(techOrdersStreamProvider(tech.id)),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: _TechStatusCard(tech: tech),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المهام الحالية', style: AppTextStyles.headlineMed),
                        _buildBadge(ref, tech.id),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
                _ordersList(ordersAsync),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (err, stack) => Scaffold(body: AppErrorWidget(message: 'خطأ في تحميل البيانات', onRetry: () {})),
    );
  }

  Widget _buildBadge(WidgetRef ref, String techId) {
    final orders = ref.watch(techOrdersStreamProvider(techId)).valueOrNull ?? [];
    final activeCount = orders.where((o) => 
      o.status != OrderStatus.completed && o.status != OrderStatus.cancelled
    ).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
      child: Text('$activeCount نشط', style: AppTextStyles.labelLarge.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
    );
  }

  Widget _ordersList(AsyncValue<List<Order>> ordersAsync) {
    return ordersAsync.when(
      data: (orders) {
        final activeOrders = orders.where((o) => 
          o.status != OrderStatus.completed && o.status != OrderStatus.cancelled
        ).toList();
        
        if (activeOrders.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('لا توجد مهام حالية.. استمتع بوقتك!'),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: _TechOrderCard(order: activeOrders[index]),
            ),
            childCount: activeOrders.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: LoadingWidget()),
      error: (e, s) => const SliverToBoxAdapter(child: SizedBox()),
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
                  final uri = WhatsAppUtils.buildUri('201014250577', message); // ضع رقم الأدمن هنا
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
      color: isAvailable ? AppColors.gold.withOpacity(0.05) : AppColors.surface2,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isAvailable ? AppColors.success.withOpacity(0.1) : AppColors.textMuted.withOpacity(0.1),
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
            onChanged: (val) {
              ref.read(techsRepositoryProvider).updateTechStatus(
                tech.id,
                val ? TechStatus.available : TechStatus.onLeave,
              );
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
          color: color.withOpacity(0.1),
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
