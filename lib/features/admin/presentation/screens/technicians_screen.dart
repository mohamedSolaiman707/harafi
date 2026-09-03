import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/error_handler.dart';
import '../providers/admin_actions_provider.dart';
import '../providers/admin_ui_providers.dart';
import '../providers/techs_provider.dart';
import '../widgets/tech_card.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';
import '../providers/wallet_recharges_provider.dart';
import 'package:intl/intl.dart' as intl;

class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techsStreamProvider);
    final searchQuery = ref.watch(adminTechSearchQueryProvider);
    final filter = ref.watch(adminTechFilterProvider);
    final width = MediaQuery.of(context).size.width;
    final sidePadding = width > 1200 ? AppSpacing.xl : AppSpacing.lg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفنيين والخبراء'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => _showTechnicianForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('إضافة فني'),
            ),
          ),
        ],
      ),
      body: techsAsync.when(
        data: (allTechs) {
          final techs = allTechs.where((t) {
            final matchesSearch = t.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                t.phone.contains(searchQuery);
            if (!matchesSearch) return false;

            if (filter == 'verified') return t.isVerified;
            if (filter == 'low_balance') return t.walletBalance < AppConstants.platformFee;
            return true;
          }).toList();

          if (allTechs.isEmpty) {
            return const Center(child: Text('لا يوجد فنيين مسجلين حالياً'));
          }

          final pendingTechs = techs.where((t) => t.status == TechStatus.pending).toList();
          final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SearchBar(
                        hintText: 'بحث باسم الفني أو رقم الهاتف...',
                        onChanged: (v) => ref.read(adminTechSearchQueryProvider.notifier).state = v,
                        leading: const Icon(Icons.search, color: AppColors.textMuted),
                        backgroundColor: WidgetStateProperty.all(AppColors.surface1),
                        elevation: WidgetStateProperty.all(0),
                        shape: WidgetStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.borderDefault),
                        )),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip(ref, 'الكل', 'all', allTechs.length),
                            const SizedBox(width: 8),
                            _filterChip(ref, 'الموثقين ⚡', 'verified', allTechs.where((t) => t.isVerified).length),
                            const SizedBox(width: 8),
                            _filterChip(ref, 'رصيد منخفض ⚠️', 'low_balance', allTechs.where((t) => t.walletBalance < AppConstants.platformFee).length, isAlert: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: _PendingWalletRechargesSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (pendingTechs.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('طلبات انضمام جديدة', pendingTechs.length, AppColors.gold),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(sidePadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 220,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => TechCard(
                        tech: pendingTechs[index],
                        onEdit: () => _showTechnicianForm(context, ref, technician: pendingTechs[index]),
                        onRecharge: () => _showRechargeDialog(context, ref, pendingTechs[index]),
                      ),
                      childCount: pendingTechs.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionHeader('الفنيين المعتمدين', approvedTechs.length, AppColors.success),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.all(sidePadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 220,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TechCard(
                      tech: approvedTechs[index],
                      onEdit: () => _showTechnicianForm(context, ref, technician: approvedTechs[index]),
                      onRecharge: () => _showRechargeDialog(context, ref, approvedTechs[index]),
                    ),
                    childCount: approvedTechs.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: AppErrorHandler.translate(err),
          error: err,
          onRetry: () => ref.invalidate(techsStreamProvider),
        ),
      ),
    );
  }

  Widget _filterChip(WidgetRef ref, String label, String value, int count, {bool isAlert = false}) {
    final currentFilter = ref.watch(adminTechFilterProvider);
    final isSelected = currentFilter == value;
    final color = isAlert ? AppColors.error : AppColors.gold;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => ref.read(adminTechFilterProvider.notifier).state = value,
      selectedColor: color,
      backgroundColor: AppColors.surface1,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF090D16) : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showRechargeDialog(BuildContext context, WidgetRef ref, Technician tech) {
    final amountController = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Row(
          children: [
            const Icon(Icons.add_card_rounded, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(child: Text('شحن محفظة: ${tech.name}', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الرصيد الحالي: ${tech.walletBalance} ج.م', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مبلغ الشحن (ج.م)', prefixIcon: Icon(Icons.payments_outlined)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [50, 100, 200, 500].map((amt) => ChoiceChip(
                label: Text('+$amt ج.م'),
                selected: amountController.text == amt.toString(),
                onSelected: (_) => amountController.text = amt.toString(),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              final amt = int.tryParse(amountController.text);
              if (amt == null || amt <= 0) return;
              Navigator.pop(ctx);

              final result = await ref.read(adminActionsProvider).rechargeTechWallet(tech.id, amt);
              if (context.mounted) {
                result.when(
                  left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                  right: (updatedTech) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم شحن محفظة ${tech.name} بمبلغ $amt ج.م بنجاح! الرصيد الجديد: ${updatedTech.walletBalance} ج.م⚡')),
                  ),
                );
              }
            },
            child: const Text('تأكيد الشحن', style: TextStyle(color: Color(0xFF090D16), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.titleLarge.copyWith(color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTechnicianForm(BuildContext context, WidgetRef ref, {Technician? technician}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: technician?.name);
    final phoneController = TextEditingController(text: technician?.phone);
    final bioController = TextEditingController(text: technician?.bio);
    final visitPriceController = TextEditingController(text: technician?.visitPrice.toString() ?? '50');
    
    String selectedGov = 'الغربية';
    String selectedCity = (technician?.area != null && technician!.area!.isNotEmpty) ? technician.area! : 'كفر الزيات';

    for (var entry in AppConstants.governoratesAndCities.entries) {
      if (entry.value.contains(technician?.area)) {
        selectedGov = entry.key;
        break;
      }
    }
    
    ServiceType selectedSpec = technician?.spec ?? ServiceType.plumbing;
    TechStatus selectedStatus = (technician?.status == TechStatus.pending) ? TechStatus.available : (technician?.status ?? TechStatus.available);
    bool isVerified = technician?.isVerified ?? false;

    final width = MediaQuery.of(context).size.width;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface1,
      constraints: BoxConstraints(maxWidth: width > 900 ? 550 : width),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: AppSpacing.xl, right: AppSpacing.xl, top: AppSpacing.xl),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(technician == null ? 'إضافة فني جديد' : 'تعديل بيانات الفني', style: AppTextStyles.headlineMed),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (technician != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDefault)),
                      child: SwitchListTile(
                        title: const Text('توثيق الحساب (Verified)'),
                        subtitle: const Text('تفعيل العلامة الزرقاء للفني لزيادة الثقة'),
                        secondary: Icon(Icons.verified, color: isVerified ? AppColors.info : AppColors.textMuted),
                        value: isVerified,
                        activeThumbColor: AppColors.info,
                        onChanged: (val) => setModalState(() => isVerified = val),
                      ),
                    ),
                    _buildVerificationDocsSection(context, technician),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف (واتساب)', prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                    enabled: technician == null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ServiceType>(
                    value: selectedSpec,
                    decoration: const InputDecoration(labelText: 'التخصص المهني', prefixIcon: Icon(Icons.home_repair_service_outlined)),
                    items: ServiceType.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                    onChanged: (v) => selectedSpec = v!,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: visitPriceController, decoration: const InputDecoration(labelText: 'سعر الزيارة', prefixIcon: Icon(Icons.monetization_on_outlined)), keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<TechStatus>(
                          value: selectedStatus,
                          decoration: const InputDecoration(labelText: 'الحالة الحالية'),
                          items: TechStatus.values.where((s) => s != TechStatus.pending).map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                          onChanged: (v) => selectedStatus = v!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGov,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'المحافظة', prefixIcon: Icon(Icons.map_outlined)),
                          dropdownColor: AppColors.surface2,
                          items: AppConstants.governoratesAndCities.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedGov = val;
                                selectedCity = AppConstants.governoratesAndCities[val]!.first;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: AppConstants.governoratesAndCities[selectedGov]!.contains(selectedCity) ? selectedCity : AppConstants.governoratesAndCities[selectedGov]!.first,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'المدينة / منطقة التغطية', prefixIcon: Icon(Icons.location_city_outlined)),
                          dropdownColor: AppColors.surface2,
                          items: (AppConstants.governoratesAndCities[selectedGov] ?? []).map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) { if (val != null) setModalState(() => selectedCity = val); },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: bioController, decoration: const InputDecoration(labelText: 'نبذة مختصرة عن الخبرة'), maxLines: 3),
                  const SizedBox(height: 32),
                  AppButton(
                    label: technician?.status == TechStatus.pending ? 'اعتماد الحساب الآن' : 'حفظ التعديلات',
                    onTap: () async {
                        if (!formKey.currentState!.validate()) return;
                        final dto = UpdateTechnicianDto(name: nameController.text.trim(), spec: selectedSpec, visitPrice: int.tryParse(visitPriceController.text), area: selectedCity, bio: bioController.text.trim(), status: selectedStatus, isVerified: isVerified);
                        final result = technician == null 
                          ? await ref.read(adminActionsProvider).addTechnician(CreateTechnicianDto(name: nameController.text.trim(), phone: phoneController.text.trim(), spec: selectedSpec, bio: bioController.text.trim(), visitPrice: int.tryParse(visitPriceController.text) ?? 50, area: selectedCity, isVerified: isVerified))
                          : await ref.read(adminActionsProvider).updateTechnician(technician.id, dto);
                        if (context.mounted) {
                          result.when(
                            left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                            right: (_) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات الفني بنجاح ✅'))); },
                          );
                        }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (technician != null)
                    TextButton.icon(style: TextButton.styleFrom(foregroundColor: AppColors.error), onPressed: () => _confirmDelete(context, ref, technician), icon: const Icon(Icons.delete_outline), label: const Text('حذف الفني نهائياً')),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Technician tech) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فني'),
        content: Text('هل أنت متأكد من حذف الفني "${tech.name}"؟ سيتم مسح كافة بياناته نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('تأكيد الحذف')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final result = await ref.read(adminActionsProvider).deleteTechnician(tech.id);
      if (context.mounted) {
        result.when(
          left: (f) => AppErrorHandler.showSnackBar(context, f.message),
          right: (_) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الفني بنجاح'))); },
        );
      }
    }
  }

  Widget _buildVerificationDocsSection(BuildContext context, Technician tech) {
    final frontUrl = tech.nationalIdFrontUrl ?? tech.identityProofUrl;
    final backUrl = tech.nationalIdBackUrl;
    final criminalUrl = tech.criminalRecordUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('مستندات التوثيق الرسمية 📄', style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold)),
              if (tech.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: AppColors.success, size: 14),
                      SizedBox(width: 4),
                      Text('موثق رسميًا', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDocPreviewCard(context, 'وجه البطاقة', frontUrl, Icons.badge_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildDocPreviewCard(context, 'ظهر البطاقة', backUrl, Icons.credit_card_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildDocPreviewCard(context, 'الفيش والتشبيه', criminalUrl, Icons.gavel_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocPreviewCard(BuildContext context, String title, String? url, IconData defaultIcon) {
    final bool hasDoc = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: hasDoc ? () => _showDocPreviewDialog(context, url, title) : null,
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasDoc ? AppColors.gold.withValues(alpha: 0.5) : AppColors.borderSubtle),
          image: hasDoc ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: hasDoc ? Colors.black.withValues(alpha: 0.35) : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(hasDoc ? Icons.visibility_outlined : defaultIcon, color: hasDoc ? Colors.white : AppColors.textMuted, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: hasDoc ? Colors.white : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                hasDoc ? 'انقر للمعاينة' : 'غير مرفوع',
                style: TextStyle(
                  color: hasDoc ? AppColors.gold : AppColors.error.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocPreviewDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (c, e, s) => const Center(child: Text('تعذر تحميل المستند 🖼️')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const CircleAvatar(backgroundColor: AppColors.surface3, child: Icon(Icons.close, color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingWalletRechargesSection extends ConsumerWidget {
  const _PendingWalletRechargesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rechargesAsync = ref.watch(walletRechargesStreamProvider);
    final width = MediaQuery.of(context).size.width;
    final sidePadding = width > 1200 ? AppSpacing.xl : AppSpacing.lg;

    return rechargesAsync.when(
      data: (allRecharges) {
        final pendingList = allRecharges.where((r) => r.isPending).toList();
        if (pendingList.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: AppCard(
            color: AppColors.gold.withValues(alpha: 0.05),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppColors.gold, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'طلبات شحن المحفظة المعلقة (${pendingList.length}) 💳',
                          style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      'يتطلب مراجعة الإيصال والاعتماد',
                      style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingList.length,
                  itemBuilder: (context, index) {
                    final item = pendingList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showImageDialog(context, item.receiptUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: AppColors.surface2,
                                child: Image.network(
                                  item.receiptUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(Icons.receipt_outlined, color: AppColors.gold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.techName} (${item.techPhone})',
                                  style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'المبلغ: ${item.amount} ج.م • محفظة المحول: ${item.senderPhone}',
                                  style: AppTextStyles.bodyMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'التاريخ: ${intl.DateFormat('d MMM, HH:mm').format(item.createdAt)}',
                                  style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () async {
                                  final res = await ref.read(adminActionsProvider).approveWalletRechargeRequest(item);
                                  res.when(
                                    left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                                    right: (_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اعتماد شحن محفظة ${item.techName} بمبلغ ${item.amount} ج.م ⚡'))),
                                  );
                                },
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('اعتماد الشحن'),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                onPressed: () async {
                                  final res = await ref.read(adminActionsProvider).rejectWalletRechargeRequest(item.id);
                                  res.when(
                                    left: (f) => AppErrorHandler.showSnackBar(context, f.message),
                                    right: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض طلب الشحن'))),
                                  );
                                },
                                child: const Text('رفض الطلب', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
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
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(backgroundColor: AppColors.surface3, child: Icon(Icons.close, color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}


