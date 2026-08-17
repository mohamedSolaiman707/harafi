import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/notification_icon.dart';
import '../../../../shared/widgets/onboarding_guide_sheet.dart';
import '../widgets/client_drawer.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/models/technician.dart';

import '../providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _trackingController = TextEditingController();
  final _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _trackingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _smartNormalize(String text) {
    String normalized = text
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');

    return normalized
        .split(' ')
        .map((word) {
      if (word.startsWith('ال') && word.length > 3) {
        return word.substring(2);
      }
      return word;
    })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final rawQuery = ref.watch(homeSearchQueryProvider);
    final query = _smartNormalize(rawQuery);

    const stopWords = [
      'عايز', 'محتاج', 'فين', 'رقم', 'حد', 'بيعمل', 'بيركب', 'بيصلح', 'فني', 'معلم',
      'صنايعي', 'ياريت', 'تركيب', 'تصليح', 'صيانة', 'مش', 'يا', 'في', 'عن', 'بتاع'
    ];

    final queryTokens = query
        .split(' ')
        .where((t) => t.length > 1 && !stopWords.contains(t))
        .toList();

    final lastTrackedCode = ref.watch(lastTrackedCodeProvider).valueOrNull;
    final userLocation = ref.watch(userLocationProvider);
    final techsAsync = ref.watch(techniciansProvider);

    final width = MediaQuery.of(context).size.width;
    const double maxContentWidth = 1100;
    final double horizontalPadding = width > maxContentWidth
        ? (width - maxContentWidth) / 2
        : AppSpacing.xl;

    final filteredCategories = ServiceCategory.values.where((category) {
      final services = ServiceType.values.where((s) {
        if (s.category != category) return false;
        if (query.isEmpty) return true;
        if (queryTokens.isEmpty) return _smartNormalize(s.label).contains(query);
        return queryTokens.any((token) {
          return _smartNormalize(s.label).contains(token) ||
              _smartNormalize(category.label).contains(token) ||
              s.keywords.any((k) => _smartNormalize(k).contains(token));
        });
      }).toList();
      return services.isNotEmpty;
    }).toList();

    final matchingTechs = query.length < 2
        ? <Technician>[]
        : (techsAsync.valueOrNull ?? []).where((t) {
      final normalizedName = _smartNormalize(t.name);
      if (queryTokens.isEmpty) return normalizedName.contains(query);
      return queryTokens.any((token) => normalizedName.contains(token));
    }).take(3).toList();

    final orders = ref.watch(ordersStreamProvider).valueOrNull ?? [];
    final activeOrder = lastTrackedCode != null
        ? orders.where((o) => o.trackingCode == lastTrackedCode &&
        o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).firstOrNull
        : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const ClientDrawer(),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context, userLocation),

              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      _buildHeader(),
                      const SizedBox(height: AppSpacing.lg),
                      _UberSearchBar(
                        controller: _searchController,
                        onChanged: (val) => ref.read(homeSearchQueryProvider.notifier).state = val,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      if (matchingTechs.isNotEmpty) ...[
                        Text('فنيون مطابقون لبحثك', style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
                        const SizedBox(height: 12),
                        ...matchingTechs.map((tech) => _TechSearchTile(tech: tech)),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      if (query.isEmpty) ...[
                        _TopRatedTechsSection(horizontalPadding: horizontalPadding),
                        const SizedBox(height: AppSpacing.xxl),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            query.isEmpty ? 'اكتشف خدماتنا' : 'نتائج البحث عن "$rawQuery"',
                            style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w900),
                          ),
                          if (query.isEmpty)
                            TextButton(
                              onPressed: () => context.push('/services'),
                              child: const Text('رؤية الكل', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),

              ...filteredCategories.map((category) {
                final services = ServiceType.values.where((s) {
                  if (s.category != category) return false;
                  if (query.isEmpty) return true;
                  if (queryTokens.isEmpty) return _smartNormalize(s.label).contains(query);
                  return queryTokens.any((token) {
                    return _smartNormalize(s.label).contains(token) ||
                        _smartNormalize(category.label).contains(token) ||
                        s.keywords.any((k) => _smartNormalize(k).contains(token));
                  });
                }).toList();

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
                          child: Text(category.label, style: AppTextStyles.headlineMed.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisSpacing: AppSpacing.lg,
                          crossAxisSpacing: AppSpacing.lg,
                          childAspectRatio: 0.9,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _OrganicServiceCard(
                            type: services[index],
                            onTap: () => context.push('/service/${services[index].name}'),
                          ),
                          childCount: services.length,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              if (filteredCategories.isEmpty && matchingTechs.isEmpty && query.isNotEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmptySearchState()),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.xxxl, horizontalPadding, 50),
                sliver: const SliverToBoxAdapter(child: _UberTrustBanner()),
              ),
            ],
          ),

          if (activeOrder != null)
            _LiveStatusFloatingBar(order: activeOrder, horizontalPadding: horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, UserLocation userLocation) {
    return SliverAppBar(
      floating: true, pinned: true, elevation: 0,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 28),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: InkWell(
        onTap: () => _showLocationPickerBottomSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 18, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(userLocation.fullLocation, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: AppColors.gold),
          onPressed: () => OnboardingGuideSheet.show(context, isTechnician: false, userName: 'عميل حرفـي'),
        ),
        const NotificationIcon(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('بيتك في إيدنا', style: AppTextStyles.displayMedium.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('أشطر الفنيين في منطقتك بضمان حرفي المعتمد', style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: AppColors.surface3),
          const SizedBox(height: 20),
          Text('لم نجد أي نتائج لبحثك', style: AppTextStyles.headlineMed),
          const SizedBox(height: 24),
          AppButton(
            label: 'عرض كل الخدمات',
            onTap: () {
              _searchController.clear();
              ref.read(homeSearchQueryProvider.notifier).state = '';
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      ),
    );
  }

  void _showLocationPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => _LocationPickerSheet(
        onLocationSelected: (city, gov) {
          ref.read(userLocationProvider.notifier).setLocation(city, gov);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _TechSearchTile extends StatelessWidget {
  final Technician tech;
  const _TechSearchTile({required this.tech});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/tech/portfolio/${tech.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: AppColors.surface1,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
            child: tech.photoUrl == null ? Text(tech.spec.icon) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tech.name, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold)),
                Text(tech.spec.label, style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _UberSearchBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _UberSearchBar({required this.controller, required this.onChanged});
  @override
  ConsumerState<_UberSearchBar> createState() => _UberSearchBarState();
}

class _UberSearchBarState extends ConsumerState<_UberSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) ref.read(homeSearchHasTextProvider.notifier).state = widget.controller.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = ref.watch(homeSearchIsFocusedProvider);
    final hasText = ref.watch(homeSearchHasTextProvider);
    return Focus(
      onFocusChange: (focused) => ref.read(homeSearchIsFocusedProvider.notifier).state = focused,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextFormField(
          controller: widget.controller, onChanged: widget.onChanged,
          style: AppTextStyles.bodyLarge, textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'ابحث عن "سباك" أو "تكييف" أو اسم فني...',
            hintStyle: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: isFocused ? AppColors.gold : AppColors.textMuted),
            suffixIcon: hasText ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () {
              widget.controller.clear();
              widget.onChanged('');
              FocusScope.of(context).unfocus();
            }) : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }
}

class _OrganicServiceCard extends StatelessWidget {
  final ServiceType type;
  final VoidCallback onTap;
  const _OrganicServiceCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/images/${_getAsset(type)}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(assetPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surface2)),
                      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.6)]))),
                      Positioned(bottom: 8, right: 12, child: Text(type.label, style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        'تبدأ من ${type.priceRange}',
                        style: AppTextStyles.labelMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
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

  String _getAsset(ServiceType t) => switch(t) {
    ServiceType.plumbing => 'sbak.jpg',
    ServiceType.electrical => 'khrba.jpg',
    ServiceType.carpentry => 'negara.jpg',
    ServiceType.ac => 'takyeefat.jpg',
    ServiceType.refrigerators => 'fridge.jpg',
    ServiceType.washingMachines => 'washing.jpg',
    ServiceType.screens => 'tv.jpg',
    ServiceType.stoves => 'gas.jpg',
  };
}

class _UberTrustBanner extends StatelessWidget {
  const _UberTrustBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface1, borderRadius: BorderRadius.circular(32),
        image: DecorationImage(
            image: const AssetImage('assets/images/back.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.75), BlendMode.darken)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 40),
          const SizedBox(height: 16),
          Text('أمانك وضمانك حقنا 🛡️', style: AppTextStyles.headlineLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('كل طلباتك محمية بضمان صيانة لمدة شهر كامل ضد عيوب الإصلاح.', style: AppTextStyles.bodyLarge.copyWith(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 24),
          AppButton(label: 'طلب فني الآن', onTap: () => context.push('/request')),
        ],
      ),
    );
  }
}

class _LiveStatusFloatingBar extends StatelessWidget {
  final Order order; final double horizontalPadding;
  const _LiveStatusFloatingBar({required this.order, required this.horizontalPadding});
  @override
  Widget build(BuildContext context) {
    return Positioned(bottom: 24, left: horizontalPadding, right: horizontalPadding, child: GestureDetector(onTap: () => context.push('/track/${order.trackingCode}'), child: Container(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 16), decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))]), child: Row(children: [
      const Icon(Icons.directions_run_rounded, color: AppColors.background, size: 24),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('طلبك قيد التنفيذ', style: AppTextStyles.titleMed.copyWith(color: AppColors.background, fontWeight: FontWeight.w900)),
        Text('تتبع حالة طلبك الآن...', style: AppTextStyles.labelMed.copyWith(color: AppColors.background.withValues(alpha: 0.7))),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)), child: Text('تتبع', style: AppTextStyles.labelLarge.copyWith(color: AppColors.background, fontWeight: FontWeight.bold))),
    ]))));
  }
}

class _TopRatedTechsSection extends ConsumerWidget {
  final double horizontalPadding;
  const _TopRatedTechsSection({required this.horizontalPadding});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topTechs = ref.watch(topRatedTechsProvider);
    if (topTechs.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('أمهر الفنيين بالقرب منك ✨', style: AppTextStyles.headlineMed.copyWith(fontWeight: FontWeight.w900)),
        TextButton(onPressed: () => context.push('/all-techs'), child: const Text('رؤية الكل', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: AppSpacing.lg),
      SizedBox(height: 195, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: topTechs.length, clipBehavior: Clip.none, itemBuilder: (context, index) {
        final tech = topTechs[index];
        return _PremiumTechCard(tech: tech);
      })),
    ]);
  }
}

class _PremiumTechCard extends StatelessWidget {
  final Technician tech;
  const _PremiumTechCard({required this.tech});

  @override
  Widget build(BuildContext context) {
    final rankColor = tech.rankColor;
    return Container(
      width: 290,
      margin: const EdgeInsets.only(left: 16, bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surface1, AppColors.surface2.withOpacity(0.95)]),
              border: Border.all(color: rankColor.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: rankColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(tech.name, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (tech.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: AppColors.info, size: 16)],
                            ],
                          ),
                          Text(tech.spec.label, style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem(Icons.star_rounded, tech.rating.toStringAsFixed(1), Colors.amber),
                      _buildInfoItem(Icons.task_alt_rounded, '${tech.totalJobs}', AppColors.success),
                      _buildInfoItem(Icons.payments_rounded, '${tech.visitPrice}ج', AppColors.info),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -20, right: 16,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tech.rankColor, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]),
              child: CircleAvatar(radius: 35, backgroundColor: AppColors.surface3, backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null, child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 30)) : null),
            ),
          ),
          Positioned(
            top: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: tech.rankColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: tech.rankColor.withOpacity(0.4))),
              child: Row(children: [Text(tech.rankEmoji, style: const TextStyle(fontSize: 10)), const SizedBox(width: 4), Text(tech.rank, style: TextStyle(color: tech.rankColor, fontSize: 9, fontWeight: FontWeight.bold))]),
            ),
          ),
          Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: () => context.push('/tech/portfolio/${tech.id}'), borderRadius: BorderRadius.circular(28)))),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(text, style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 11))]);
  }
}

class _LocationPickerSheet extends ConsumerWidget {
  final Function(String city, String gov) onLocationSelected;
  const _LocationPickerSheet({required this.onLocationSelected});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = ref.watch(userLocationProvider);
    final selectedGov = ref.watch(homeSelectedGovProvider);
    final citiesMap = AppConstants.governoratesAndCities;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: AppSpacing.lg),
          Text('اختر منطقتك 📍', style: AppTextStyles.headlineMed.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: citiesMap.keys.map((gov) {
                final isSelected = gov == selectedGov;
                return Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(gov), selected: isSelected, selectedColor: AppColors.gold, backgroundColor: AppColors.surface2,
                    labelStyle: TextStyle(color: isSelected ? const Color(0xFF090D16) : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    onSelected: (_) => ref.read(homeSelectedGovProvider.notifier).state = gov,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: citiesMap[selectedGov]?.length ?? 0,
              itemBuilder: (context, index) {
                final city = citiesMap[selectedGov]![index];
                final isCurrent = city == currentLocation.city && selectedGov == currentLocation.governorate;
                return ListTile(
                  title: Text(city, style: AppTextStyles.titleLarge.copyWith(color: isCurrent ? AppColors.gold : AppColors.textPrimary, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                  trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: AppColors.gold) : null,
                  onTap: () => onLocationSelected(city, selectedGov),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
