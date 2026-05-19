import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_badge.dart';
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
    final columns = width > 900
        ? 3
        : width > 600
        ? 2
        : 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surface2,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () => context.push('/admin'),
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'دخول الإدارة',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                AppConstants.appName,
                style: AppTextStyles.titleMed.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.background, AppColors.surface2],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'بيتك في إيدنا',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'خدمات منزلية سريعة وآمنة في كفر الزيات',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختر الخدمة المناسبة',
                        style: AppTextStyles.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'أطلب فني سباكة أو كهرباء أو نجارة خلال دقائق مع سعر واضح وشغل مضمون.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: width > 900 ? 1.1 : 1.3,
                        children: ServiceType.values.map((type) {
                          return _ServiceCard(
                            type: type,
                            isSelected: false,
                            onTap: () => context.push('/request', extra: type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _WhyTrustSection(),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'سجل طلبك الآن',
                        onTap: () => context.push('/request'),
                        icon: Icons.arrow_forward_ios,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'تتبع طلبك بسهولة',
                        style: AppTextStyles.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'أدخل كود التتبع',
                        hint: 'مثال: A1B2C3D4',
                        controller: _trackingController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'تتبع',
                        onTap: () {
                          if (_trackingController.text.isNotEmpty) {
                            context.push('/track/${_trackingController.text}');
                          }
                        },
                        variant: ButtonVariant.ghost,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: isSelected
          ? AppColors.primaryDark.withAlpha(40)
          : AppColors.surface3,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(type.icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            type.label,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyTrustSection extends StatelessWidget {
  const _WhyTrustSection();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: const [
        AppBadge(label: 'سعر واضح', variant: BadgeVariant.success),
        AppBadge(label: 'شغل مضمون', variant: BadgeVariant.info),
        AppBadge(label: 'فنيين معتمدين', variant: BadgeVariant.success),
      ],
    );
  }
}
