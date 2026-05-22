import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/enums/service_type.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _trackingController = TextEditingController();

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const double maxContentWidth = 1100;
    final double horizontalPadding = width > maxContentWidth 
        ? (width - maxContentWidth) / 2 
        : AppSpacing.xl;

    int crossAxisCount = 2;
    if (width > 1200) crossAxisCount = 5;
    else if (width > 900) crossAxisCount = 4;
    else if (width > 600) crossAxisCount = 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.surface2,
            automaticallyImplyLeading: false,
            actions: [
              Padding(
                padding: EdgeInsetsDirectional.only(end: horizontalPadding),
                child: _buildAdminAction(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: EdgeInsetsDirectional.only(
                start: horizontalPadding,
                bottom: 16,
              ),
              title: Text(
                AppConstants.appName,
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              background: _buildHeaderBackground(horizontalPadding),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.xl, horizontalPadding, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickTrackAction(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildSectionHeader(context, 'خدماتنا المتميزة'),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),

          // عرض الخدمات مقسمة حسب الفئات
          ...ServiceCategory.values.map((category) {
            final services = ServiceType.values.where((s) => s.category == category).toList();
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Row(
                        children: [
                          Text(category.icon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            category.label,
                            style: AppTextStyles.headlineMed.copyWith(color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: AppSpacing.lg,
                      crossAxisSpacing: AppSpacing.lg,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ServiceCard(
                        type: services[index],
                        onTap: () => context.push('/request', extra: services[index]),
                      ),
                      childCount: services.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                ],
              ),
            );
          }),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.xxl, horizontalPadding, 60),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const _WhyTrustSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: AppButton(
                        label: 'سجل طلب خاص الآن',
                        onTap: () => context.push('/request'),
                        variant: ButtonVariant.primary,
                        icon: Icons.add_task_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAction() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface3.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => context.push('/admin'),
        icon: const Icon(
          Icons.admin_panel_settings_outlined,
          color: AppColors.gold,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(double padding) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface1, AppColors.surface2, AppColors.background],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildLocationBadge(),
              const SizedBox(height: 16),
              Text(
                'بيتك في إيدنا',
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'خدمات منزلية ذكية وسريعة وآمنة في كفر الزيات',
                style: AppTextStyles.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 14, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            'كفر الزيات الآن',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.headlineMed),
        TextButton(
          onPressed: () => context.push('/services'),
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          child: Row(
            children: const [
              Text('الكل'),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTrackAction() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: AppColors.gold, size: 32),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تتبع طلبك الآن', style: AppTextStyles.titleLarge),
                Text('اعرف مكان الفني وحالة طلبك', style: AppTextStyles.bodyMed),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _showTrackBottomSheet(context),
            child: const Text('تتبع'),
          ),
        ],
      ),
    );
  }

  void _showTrackBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: AppSpacing.xl),
            Text('أدخل كود التتبع', textAlign: TextAlign.center, style: AppTextStyles.headlineMed),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'كود التتبع',
              hint: 'مثال: A1B2C3D4',
              controller: _trackingController,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'بدء التتبع',
              onTap: () {
                if (_trackingController.text.isNotEmpty) {
                  Navigator.pop(context);
                  context.push('/track/${_trackingController.text}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceType type;
  final VoidCallback onTap;

  const _ServiceCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.surface3.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: AppColors.surface1, shape: BoxShape.circle),
                  child: Text(type.icon, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  type.label, 
                  textAlign: TextAlign.center, 
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'أطلب الآن', 
                  style: AppTextStyles.labelMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhyTrustSection extends StatelessWidget {
  const _WhyTrustSection();

  @override
  Widget build(BuildContext context) {
    final features = [
      {'icon': Icons.verified_user_rounded, 'label': 'فنيين معتمدين'},
      {'icon': Icons.timer_rounded, 'label': 'سرعة استجابة'},
      {'icon': Icons.payments_rounded, 'label': 'أسعار عادلة'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: features.map((f) => Expanded(
          child: Column(
            children: [
              Icon(f['icon'] as IconData, color: AppColors.gold, size: 24),
              const SizedBox(height: 8),
              Text(
                f['label'] as String, 
                textAlign: TextAlign.center, 
                style: AppTextStyles.labelMed.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
