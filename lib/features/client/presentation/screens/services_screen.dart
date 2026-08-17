import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/enums/service_type.dart';

final selectedCategoryProvider = StateProvider<ServiceCategory?>((ref) => null);

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final width = MediaQuery.of(context).size.width;

    final filteredServices = ServiceType.values.where((s) {
      if (selectedCategory == null) return true;
      return s.category == selectedCategory;
    }).toList();

    int crossAxisCount = width > 900 ? 4 : 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الخدمات المتاحة'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Organic Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterTab(
                          label: 'الكل',
                          isSelected: selectedCategory == null,
                          onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
                        ),
                        ...ServiceCategory.values.map((cat) => _FilterTab(
                          label: cat.label,
                          isSelected: selectedCategory == cat,
                          onTap: () => ref.read(selectedCategoryProvider.notifier).state = cat,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Organic Grid with Local Photos
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ServicePhotoCard(type: filteredServices[index]),
                childCount: filteredServices.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold : AppColors.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: isSelected ? Colors.black : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServicePhotoCard extends StatelessWidget {
  final ServiceType type;
  const _ServicePhotoCard({required this.type});

  // ماب للصور الحقيقية من المجلد المحلي
  String _getAssetPath(ServiceType type) {
    const path = 'assets/images/';
    return switch (type) {
      ServiceType.plumbing => '${path}sbak.jpg',
      ServiceType.electrical => '${path}khrba.jpg',
      ServiceType.carpentry => '${path}negara.jpg',
      ServiceType.ac => '${path}takyeefat.jpg',
      ServiceType.refrigerators => '${path}fridge.jpg',
      ServiceType.washingMachines => '${path}washing.jpg',
      ServiceType.screens => '${path}tv.jpg',
      ServiceType.stoves => '${path}gas.jpg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/service/${type.name}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top: Local Photo
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        _getAssetPath(type),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surface2,
                          child: Center(child: Text(type.icon, style: const TextStyle(fontSize: 40))),
                        ),
                      ),
                      // Subtle gradient overlay for better text contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom: Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          type.label,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type.priceRange,
                          style: AppTextStyles.labelMed.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
