import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/enums/service_type.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    // حساب عدد الأعمدة ديناميكياً
    int crossAxisCount = 2;
    if (width > 1200) crossAxisCount = 5;
    else if (width > 900) crossAxisCount = 4;
    else if (width > 600) crossAxisCount = 3;

    // حساب نسبة الطول للعرض لتجنب التمدد القبيح
    double aspectRatio = 0.8;
    if (width > 900) aspectRatio = 0.9;
    if (width > 1200) aspectRatio = 1.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('كل الخدمات'),
        backgroundColor: AppColors.surface2,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200), // تحجيم المحتوى في المنتصف
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.xl),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.lg,
              crossAxisSpacing: AppSpacing.lg,
              childAspectRatio: aspectRatio,
            ),
            itemCount: ServiceType.values.length,
            itemBuilder: (context, index) {
              final type = ServiceType.values[index];
              return _ServiceItem(
                type: type,
                onTap: () => context.push('/request', extra: type),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final ServiceType type;
  final VoidCallback onTap;

  const _ServiceItem({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion( // إضافة تأثير الماوس للويب
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.surface3.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: -5,
                      )
                    ],
                  ),
                  child: Text(type.icon, style: const TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  type.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'أطلب الآن',
                  style: AppTextStyles.labelMed.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
