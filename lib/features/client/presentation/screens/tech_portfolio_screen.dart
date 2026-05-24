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
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final url = Uri.base.toString(); 
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ رابط البروفايل للمشاركة')),
              );
            },
            tooltip: 'مشاركة البروفايل',
          ),
        ],
      ),
      body: techsAsync.when(
        data: (techs) {
          final tech = techs.where((t) => t.id == techId).firstOrNull;
          if (tech == null) return const Center(child: Text('تعذر العثور على بيانات الفني'));
          
          return techOrdersAsync.when(
            data: (orders) => _PortfolioBody(tech: tech, orders: orders),
            loading: () => const LoadingWidget(),
            error: (e, s) => _PortfolioBody(tech: tech, orders: const []),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final Technician tech;
  final List<Order> orders;
  const _PortfolioBody({required this.tech, required this.orders});

  @override
  Widget build(BuildContext context) {
    final isAvailable = tech.status == TechStatus.available;
    final reviews = orders.where((o) => o.rating != null && o.rating! > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.xxl),
              _buildStatsRow(),
              const SizedBox(height: AppSpacing.xxl),
              _buildBioSection(),
              const SizedBox(height: AppSpacing.xxl),
              
              if (tech.portfolioImages.isNotEmpty) ...[
                _buildSectionHeader('سابق أعمالنا'),
                const SizedBox(height: AppSpacing.lg),
                _buildPortfolioGallery(context),
                const SizedBox(height: AppSpacing.xxl),
              ],

              if (reviews.isNotEmpty) ...[
                _buildSectionHeader('آراء العملاء (${reviews.length})'),
                const SizedBox(height: AppSpacing.lg),
                ...reviews.take(3).map((r) => _ReviewItem(order: r)),
                if (reviews.length > 3)
                  TextButton(onPressed: () {}, child: const Text('عرض الكل')),
                const SizedBox(height: AppSpacing.xxl),
              ],

              AppButton(
                label: isAvailable ? 'أطلب هذا الفني الآن' : 'الفني مشغول حالياً',
                icon: isAvailable ? Icons.build_circle : Icons.timer_outlined,
                variant: isAvailable ? ButtonVariant.primary : ButtonVariant.ghost,
                onTap: isAvailable ? () => context.push('/request', extra: {'service': tech.spec, 'techId': tech.id}) : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'اتصال مباشر بالفني',
                icon: Icons.phone,
                variant: ButtonVariant.success,
                onTap: () => launchUrl(Uri.parse('tel:${tech.phone}')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
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
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                child: tech.photoUrl == null 
                    ? Text(tech.spec.icon, style: const TextStyle(fontSize: 48))
                    : null,
              ),
            ),
            // بادج التوثيق فوق الصورة
            if (tech.isVerified)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                child: const Icon(Icons.verified, color: AppColors.info, size: 24),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        
        // رتبة الفني (Rank Badge)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tech.rankColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tech.rankColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tech.rankIcon, color: tech.rankColor, size: 14),
              const SizedBox(width: 6),
              Text(
                tech.rank,
                style: AppTextStyles.labelLarge.copyWith(color: tech.rankColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        Text(tech.name, style: AppTextStyles.displayMedium),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tech.spec.label,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(tech.area ?? 'كفر الزيات', style: AppTextStyles.bodyMed),
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

  Widget _buildBioSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('عن الفني وخبراته', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tech.bio ?? 'هذا الفني خبير معتمد في شبكة حرفي، يلتزم بتقديم أفضل جودة وأسرع استجابة لعملائنا.',
            style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioGallery(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tech.portfolioImages.length,
        itemBuilder: (context, index) {
          final imageUrl = tech.portfolioImages[index];
          return GestureDetector(
            onTap: () => _showFullScreenImage(context, imageUrl),
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: AppColors.borderDefault),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                ],
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  size: 14,
                )),
              ),
            ],
          ),
          if (order.ratingComment != null && order.ratingComment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              order.ratingComment!,
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
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
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.headlineMed),
        Text(label, style: AppTextStyles.labelMed, textAlign: TextAlign.center),
      ],
    );
  }
}
