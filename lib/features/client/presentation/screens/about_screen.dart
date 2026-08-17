import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('عن حرفي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          children: [
            // App Logo & Identity
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Color(0xFF131B2A),
                      backgroundImage: AssetImage(
                        'assets/images/logo1.png',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'حرفي | Harafi',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لما تحتاج حد يعرف شغله',
                    style: AppTextStyles.bodyMed.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // About Section
            _buildSection(
              title: 'من نحن؟',
              content:
              'حرفي هي منصة رقمية بتهدف لتطوير مفهوم الخدمات المنزلية في مصر. '
                  'إحنا بنربطك بنخبة من الفنيين المهرة في مختلف التخصصات (سباكة، كهرباء، نجارة...) '
                  'عشان نضمن لك خدمة محترفة، سريعة، وبأمان تام.',
            ),

            const SizedBox(height: 32),

            // Our Values & Guarantee
            _buildSectionHeader('ليه حرفي؟'),
            const SizedBox(height: 16),

            _buildValueItem(
              icon: Icons.shield_rounded,
              title: 'ضمان حرفي لمدة شهر 🛡️',
              description:
              'بعد ما الفني يخلص شغله وتأكد إتمام الطلب من التطبيق، بيتفعل لك تلقائياً ضمان لمدة 30 يوم على نفس العطل. لو المشكلة رجعت تاني، بنتابع معاك ومع الفني لحد ما تتحل.',
            ),

            _buildValueItem(
              icon: Icons.verified_user_rounded,
              title: 'حفظ حقك',
              description:
              'تأكيد إتمام الخدمة من خلال التطبيق هو الضمان الوحيد لحقك. إحنا بنضمن إن التعامل يكون احترافي وبأعلى جودة.',
            ),

            _buildValueItem(
              icon: Icons.search_rounded,
              title: 'سهولة الوصول',
              description:
              'بدل ما تدور وتغلب في السؤال عن رقم فني، بضغطة واحدة بنوصلك بأقرب حد يعرف شغله في منطقتك.',
            ),

            _buildValueItem(
              icon: Icons.visibility_outlined,
              title: 'وضوح وشفافية',
              description:
              'نهتم إن تفاصيل الطلب والتواصل بين العميل والفني تكون واضحة من بداية الخدمة لحد انتهائها.',
            ),

            const SizedBox(height: 40),

            // Guarantee Notice Highlight
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.25),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.health_and_safety_rounded,
                    color: AppColors.gold,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تأكيد الخدمة = تفعيل ضمانك',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'عشان تستفيد بضمان الـ 30 يوم، لازم تأكد إتمام الخدمة من داخل التطبيق بعد ما الفني يخلص شغله. ده الإجراء اللي بيضمن حقك لو العطل ظهر تاني.',
                    style: AppTextStyles.bodyMed.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Location
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.gold,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مقرنا الرئيسي',
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الغربية، كفر الزيات – مصر',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Footer
            Text(
              'جميع الحقوق محفوظة © ${DateTime.now().year} حرفي',
              style: AppTextStyles.labelMed.copyWith(
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'حرفي... لما تحتاج حد يعرف شغله',
              style: AppTextStyles.bodyMed.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 12),
        Text(
          content,
          style: AppTextStyles.bodyLarge.copyWith(
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.headlineMed,
        ),
      ],
    );
  }

  Widget _buildValueItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: AppColors.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodyMed.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
