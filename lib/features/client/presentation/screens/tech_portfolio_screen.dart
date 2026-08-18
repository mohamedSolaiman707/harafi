import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/order.dart';

class TechPortfolioScreen extends ConsumerWidget {
  final String techId;
  const TechPortfolioScreen({super.key, required this.techId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techniciansProvider);
    final techOrdersAsync = ref.watch(techOrdersStreamProvider(techId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي للفني'),
      ),
      body: Builder(builder: (context) {
        final techs = techsAsync.valueOrNull;

        if (techs == null && techsAsync.isLoading) {
          return const LoadingWidget();
        }
        if (techs == null) {
          return Center(child: Text('خطأ: ${techsAsync.error}'));
        }

        final tech = techs.where((t) => t.id == techId).firstOrNull;
        if (tech == null) return const Center(child: Text('تعذر العثور على بيانات الفني'));

        final orders = techOrdersAsync.valueOrNull ?? const [];
        final isOrdersLoading = techOrdersAsync.isLoading;

        return _PortfolioBody(tech: tech, orders: orders, isOrdersLoading: isOrdersLoading);
      }),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final Technician tech;
  final List<Order> orders;
  final bool isOrdersLoading;
  const _PortfolioBody({
    required this.tech, 
    required this.orders, 
    this.isOrdersLoading = false
  });

  @override
  Widget build(BuildContext context) {
    // استخدام المنطق الجوكر
    final canBook = tech.canAcceptOrders;
    final reviews = orders.where((o) => o.rating != null && o.rating! > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsRow(),
              const SizedBox(height: AppSpacing.md),
              _buildTrustBadges(),
              const SizedBox(height: AppSpacing.lg),
              _buildBioSection(),
              const SizedBox(height: AppSpacing.lg),
              
              if (tech.portfolioImages.isNotEmpty) ...[
                _buildSectionHeader('سابق أعمالنا'),
                const SizedBox(height: AppSpacing.md),
                _buildPortfolioGallery(context),
                const SizedBox(height: AppSpacing.lg),
              ],

              _buildSectionHeader('آراء العملاء'),
              const SizedBox(height: AppSpacing.md),
              if (isOrdersLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
                )
              else if (reviews.isEmpty)
                Text('لا توجد تقييمات لهذا الفني بعد.', style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted))
              else
                ...reviews.take(3).map((r) => _ReviewItem(order: r)),
              
              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: canBook ? 'أطلب هذا الفني الآن' : 'الفني غير متاح حالياً',
                icon: canBook ? Icons.build_circle : Icons.timer_off_outlined,
                variant: canBook ? ButtonVariant.primary : ButtonVariant.ghost,
                onTap: canBook ? () => context.push('/request', extra: {'service': tech.spec, 'techId': tech.id}) : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'اتصال مباشر بالفني',
                icon: Icons.phone,
                variant: ButtonVariant.success,
                onTap: () => launchUrl(Uri.parse('tel:${tech.phone}')),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.headlineMed),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Hero(
              tag: 'tech-avatar-${tech.id}',
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tech.rankColor.withOpacity(0.5), width: 2),
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: AppColors.gold.withOpacity(0.1),
                  backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                  child: tech.photoUrl == null 
                      ? Text(tech.spec.icon, style: const TextStyle(fontSize: 32))
                      : null,
                ),
              ),
            ),
            if (tech.isVerified)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                child: const Icon(Icons.verified, color: AppColors.info, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (tech.canAcceptOrders ? tech.rankColor : AppColors.textMuted).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tech.canAcceptOrders ? tech.rankIcon : Icons.timer_off_outlined, 
                   color: tech.canAcceptOrders ? tech.rankColor : AppColors.textMuted, size: 12),
              const SizedBox(width: 4),
              Text(
                tech.canAcceptOrders ? tech.rank : 'غير متاح حالياً',
                style: AppTextStyles.labelLarge.copyWith(
                  color: tech.canAcceptOrders ? tech.rankColor : AppColors.textMuted, 
                  fontWeight: FontWeight.bold, fontSize: 10
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 4),
        Text(tech.name, style: AppTextStyles.headlineLarge),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tech.spec.label,
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 2),
            Text(tech.area ?? 'كفر الزيات', style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(label: 'التقييم', value: tech.rating.toStringAsFixed(1), icon: Icons.star, color: Colors.amber),
        _StatItem(label: 'عملية ناجحة', value: tech.totalJobs.toString(), icon: Icons.verified_user, color: AppColors.success),
        _StatItem(label: 'سعر الزيارة', value: '${tech.visitPrice} ج.م', icon: Icons.payments, color: AppColors.info),
      ],
    );
  }

  Widget _buildTrustBadges() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _TrustBadge(
            icon: Icons.verified_rounded,
            label: tech.isVerified ? 'فني موثق' : 'قيد التوثيق',
            color: tech.isVerified ? AppColors.info : AppColors.textMuted,
          ),
          const _TrustBadge(
            icon: Icons.shield_outlined,
            label: 'ضمان 30 يوم',
            color: AppColors.success,
          ),
          const _TrustBadge(
            icon: Icons.speed_rounded,
            label: 'استجابة سريعة',
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('عن الفني وخبراته', style: AppTextStyles.titleMed),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tech.bio ?? 'هذا الفني خبير معتمد في شبكة حرفي، يلتزم بتقديم أفضل جودة وأسرع استجابة لعملائنا.',
            style: AppTextStyles.bodyMed.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioGallery(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tech.portfolioImages.length,
        itemBuilder: (context, index) {
          final imageUrl = tech.portfolioImages[index];
          return GestureDetector(
            onTap: () => _showFullScreenImage(context, imageUrl),
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: AppColors.borderDefault),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Order order;
  const _ReviewItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.clientName, style: AppTextStyles.titleMed),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < (order.rating ?? 0) ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                  size: 12,
                )),
              ),
            ],
          ),
          if (order.ratingComment != null && order.ratingComment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              order.ratingComment!,
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.titleMed),
        Text(label, style: AppTextStyles.labelMed, textAlign: TextAlign.center),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TrustBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelMed.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
