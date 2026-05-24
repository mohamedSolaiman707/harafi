import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../widgets/client_drawer.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/models/order.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _trackingController = TextEditingController();
  final _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  String? _lastTrackedCode;

  @override
  void initState() {
    super.initState();
    _loadLastTrackedCode();
  }

  Future<void> _loadLastTrackedCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastTrackedCode = prefs.getString('last_tracked_code');
    });
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _searchController.dispose();
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

    final filteredCategories = ServiceCategory.values.where((category) {
      final services = ServiceType.values.where((s) => 
        s.category == category && 
        (s.label.contains(_searchQuery) || category.label.contains(_searchQuery))
      ).toList();
      return services.isNotEmpty;
    }).toList();

    // البحث عن الطلب النشط لإظهار البار
    final orders = ref.watch(ordersStreamProvider).valueOrNull ?? [];
    final activeOrder = _lastTrackedCode != null 
        ? orders.where((o) => o.trackingCode == _lastTrackedCode && 
            o.status != OrderStatus.completed && 
            o.status != OrderStatus.cancelled).firstOrNull
        : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const ClientDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => launchUrl(WhatsAppUtils.buildUri('201014250577', 'السلام عليكم، أحتاج مساعدة في منصة حرفي')),
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.support_agent, color: Colors.white),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.surface2,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppColors.gold, size: 28),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: horizontalPadding),
                    child: _buildAdminAction(),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: EdgeInsetsDirectional.only(
                    start: horizontalPadding + 56,
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
                      _buildQuickActions(),
                      const SizedBox(height: AppSpacing.xl),
                      
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن خدمة (سباكة، تكييف، كهرباء...)',
                          prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                          suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }))
                            : null,
                        ),
                      ),
                      
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        _TopRatedTechsSection(horizontalPadding: horizontalPadding),
                      ],

                      const SizedBox(height: AppSpacing.xxl),
                      _buildSectionHeader(context, _searchQuery.isEmpty ? 'خدماتنا المتميزة' : 'نتائج البحث'),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),

              ...filteredCategories.map((category) {
                final services = ServiceType.values.where((s) => 
                  s.category == category && s.label.contains(_searchQuery)
                ).toList();
                
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
                            onTap: () => context.push('/service/${services[index].name}'),
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
                padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.xxl, horizontalPadding, 100),
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
          
          // ويدجت الحالة الحية
          if (activeOrder != null)
            _LiveStatusFloatingBar(order: activeOrder, horizontalPadding: horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            title: 'تتبع طلب',
            subtitle: 'بالكود الخاص بك',
            icon: Icons.local_shipping_outlined,
            onTap: () => _showTrackBottomSheet(context),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionCard(
            title: 'المفضلين',
            subtitle: 'فنييك المختارين',
            icon: Icons.favorite_border_rounded,
            onTap: () => context.push('/favorites'),
          ),
        ),
      ],
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface1, AppColors.surface2, AppColors.background],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
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
            ),
            const SizedBox(height: 16),
            Text(
              'بيتك في إيدنا',
              style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.headlineMed),
        if (_searchQuery.isEmpty)
          TextButton(
            onPressed: () => context.push('/services'),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            child: const Row(
              children: [
                Text('الكل'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12),
              ],
            ),
          ),
      ],
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

class _LiveStatusFloatingBar extends StatelessWidget {
  final Order order;
  final double horizontalPadding;
  const _LiveStatusFloatingBar({required this.order, required this.horizontalPadding});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: horizontalPadding,
      right: horizontalPadding,
      child: GestureDetector(
        onTap: () => context.push('/track/${order.trackingCode}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: [
              BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: Colors.black, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('طلبك قيد التنفيذ', style: AppTextStyles.titleMed.copyWith(color: Colors.black)),
                    Text(
                      'الحالة: ${order.status.label}',
                      style: AppTextStyles.bodyMed.copyWith(color: Colors.black.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopRatedTechsSection extends ConsumerWidget {
  final double horizontalPadding;
  const _TopRatedTechsSection({required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topTechs = ref.watch(topRatedTechsProvider);
    if (topTechs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('أمهر الفنيين في كفر الزيات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topTechs.length,
            itemBuilder: (context, index) {
              final tech = topTechs[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(left: 16),
                child: AppCard(
                  onTap: () => context.push('/tech/portfolio/${tech.id}'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'tech-avatar-${tech.id}',
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.surface1,
                          backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                          child: tech.photoUrl == null ? Text(tech.spec.icon, style: const TextStyle(fontSize: 24)) : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(child: Text(tech.name, style: AppTextStyles.titleMed, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                if (tech.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: AppColors.info, size: 14),
                                ],
                              ],
                            ),
                            Text(tech.spec.label, style: AppTextStyles.labelMed.copyWith(color: AppColors.gold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(tech.rating.toStringAsFixed(1), style: AppTextStyles.labelLarge),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surface2,
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMed),
                Text(subtitle, style: AppTextStyles.labelMed),
              ],
            ),
          ),
        ],
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
                  'تصفح الفنيين', 
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
