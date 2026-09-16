import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/client/presentation/providers/client_screen_providers.dart';
import 'app_button.dart';

/// الشيت التفاعلي لشرح التطبيق ودليل الانطلاق للفني والعميل
class OnboardingGuideSheet extends ConsumerStatefulWidget {
  final bool isTechnician;
  final String userName;
  final String? userArea;

  const OnboardingGuideSheet({
    super.key,
    required this.isTechnician,
    required this.userName,
    this.userArea,
  });

  static void show(BuildContext context, {required bool isTechnician, required String userName, String? userArea}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OnboardingGuideSheet(
        isTechnician: isTechnician,
        userName: userName,
        userArea: userArea,
      ),
    );
  }

  @override
  ConsumerState<OnboardingGuideSheet> createState() => _OnboardingGuideSheetState();
}

class _OnboardingGuideSheetState extends ConsumerState<OnboardingGuideSheet> {
  final PageController _pageController = PageController();

  List<_GuideStep> get _steps {
    if (widget.isTechnician) {
      return [
        _GuideStep(
          icon: Icons.celebration_rounded,
          badge: 'هدية انضمام 100 ج.م 🎁',
          badgeColor: AppColors.success,
          title: 'أهلاً بك يا مهندس ${widget.userName}! 🎉',
          subtitle: 'مبروك انضمامك لمنصة حرفـي، تمت إضافة 100 ج.م رصيد ترحيبي مجاني في محفظتك لتغطية أولى عملياتك فوراً وبدون أي تكاليف مسبقة!',
          accentColor: AppColors.gold,
        ),
        _GuideStep(
          icon: Icons.handyman_rounded,
          badge: 'استقبال وحجز الطلبات 📲',
          badgeColor: AppColors.info,
          title: 'كيف تصلك المشاوير والطلبات؟',
          subtitle: 'تصلك طلبات الصيانة من العملاء القريبين منك في منطقة (${widget.userArea ?? 'تغطيتك'}). يمكنك التبديل لحالة (متفرغ 🟢) في أي وقت، والتواصل مباشر 100% مع العملاء.',
          accentColor: AppColors.info,
        ),
        _GuideStep(
          icon: Icons.account_balance_wallet_rounded,
          badge: 'عمولة عادلة ومحفظة مرنة 💳',
          badgeColor: AppColors.gold,
          title: 'نظام الأرباح والعمولة',
          subtitle: 'المنصة تخصم 30 ج.م ثابتة فقط عند إكمال كل طلب بنجاح. باقي أرباحك ملك لك بالكامل! ويمكنك إعادة شحن المحفظة فوراً عبر فودافون كاش أو إنستا باي.',
          accentColor: AppColors.gold,
        ),
        _GuideStep(
          icon: Icons.workspace_premium_rounded,
          badge: 'الرتب والأولويات 🏆',
          badgeColor: Colors.purpleAccent,
          title: 'ارتقِ برتبتك لتتصدر نتائج البحث',
          subtitle: 'من فني صاعد 🥉 إلى محترف 🥈 وصولاً لحرفي بلاتيني 💎 كلما زادت تقييماتك وإنجازاتك، تصدرت شاشات العملاء وحصلت على أكبر قدر من الطلبات!',
          accentColor: Colors.purpleAccent,
        ),
      ];
    } else {
      return [
        _GuideStep(
          icon: Icons.handyman_rounded,
          badge: 'دليل استخدام تطبيق حرفي 🛠️',
          badgeColor: AppColors.gold,
          title: 'أهلاً بك يا ${widget.userName}! 👋',
          subtitle: 'حرفي يربطك بأفضل وأمهر الفنيين المعتمدين والموثوقين في منطقتك بكل سهولة وسرعة وبدون أي عمولات خفية.',
          accentColor: AppColors.gold,
        ),
        _GuideStep(
          icon: Icons.phone_in_talk_rounded,
          badge: 'تواصل مباشر مع الفني 📞',
          badgeColor: AppColors.success,
          title: 'اتصال وواتساب مباشر بدون وسيط',
          subtitle: 'يمكنك اختيار الفني حسب التقييم والمجال والتواصل معه مباشرة هاتفياً أو عبر الواتساب لتحديد تفاصيل وموعد المعاينة.',
          accentColor: AppColors.success,
        ),
        _GuideStep(
          icon: Icons.star_rounded,
          badge: 'ضمان التقييم والجودة ⭐',
          badgeColor: AppColors.info,
          title: 'تتبع طلبك وقيّم تجربتك',
          subtitle: 'تتبع حالة طلبك خطوة بخطوة من (بدء الحركة) وحتى (إكمال العمل)، ثم شارك تقييمك لمساعدة باقي العملاء في اختيار الأفضل.',
          accentColor: AppColors.info,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final currentPage = ref.watch(onboardingPageIndexProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: MainAxisSizeColumn(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض السحب الأعلى
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderDefault,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // المحتوى التفاعلي السلايدر
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _pageController,
              itemCount: steps.length,
              onPageChanged: (idx) => ref.read(onboardingPageIndexProvider.notifier).state = idx,
              itemBuilder: (ctx, index) {
                final step = steps[index];
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // أيقونة الميزة بدائرة فخمة
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: step.accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: step.accentColor.withValues(alpha: 0.4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: step.accentColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                            )
                          ],
                        ),
                        child: Icon(step.icon, size: 48, color: step.accentColor),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // شارة السلايد
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: step.badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: step.badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          step.badge,
                          style: TextStyle(
                            color: step.badgeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // العنوان الرئيسي
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // الوصف والشرح
                      Text(
                        step.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMed.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // مؤشر الصفحات (Page Indicator Dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              steps.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: currentPage == index ? AppColors.gold : AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // أزرار التنقل والإنهاء
          Row(
            children: [
              if (currentPage < steps.length - 1)
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تخطي', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: currentPage == steps.length - 1
                      ? (widget.isTechnician ? 'انطلق وابدأ الآن 🚀' : 'تصفح الخدمات الآن 🚀')
                      : 'التالي ➔',
                  onTap: () {
                    if (currentPage < steps.length - 1) {
                      _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MainAxisSizeColumn extends StatelessWidget {
  final MainAxisSize mainAxisSize;
  final List<Widget> children;
  const MainAxisSizeColumn({super.key, required this.mainAxisSize, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _GuideStep {
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final Color accentColor;

  _GuideStep({
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}
