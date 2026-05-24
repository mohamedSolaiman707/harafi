import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  ServiceType? _selectedService;
  String? _preSelectedTechId;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedClientData();
  }

  Future<void> _loadSavedClientData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('client_name') ?? '';
      _phoneController.text = prefs.getString('client_phone') ?? '';
      _areaController.text = prefs.getString('client_area') ?? '';
    });
  }

  Future<void> _saveClientData(String trackingCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('client_name', _nameController.text.trim());
    await prefs.setString('client_phone', _phoneController.text.trim());
    await prefs.setString('client_area', _areaController.text.trim());
    await prefs.setString('last_tracked_code', trackingCode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is ServiceType) {
        _selectedService = extra;
      } else if (extra is Map<String, dynamic>) {
        _selectedService = extra['service'] as ServiceType?;
        _preSelectedTechId = extra['techId'] as String?;
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار نوع الخدمة أولاً')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final order = Order(
        id: '',
        trackingCode: '',
        clientName: _nameController.text.trim(),
        clientPhone: _phoneController.text.trim(),
        service: _selectedService!,
        area: _areaController.text.trim(),
        description: _descriptionController.text.trim(),
        techId: _preSelectedTechId,
        status: _preSelectedTechId != null ? OrderStatus.assigned : OrderStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ref.read(adminActionsProvider).createOrder(order);

      result.when(
        left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${f.message}'))),
        right: (createdOrder) async {
          await _saveClientData(createdOrder.trackingCode);
          if (mounted) _showSuccessDialog(createdOrder);
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ غير متوقع: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(Order result) {
    Technician? tech;
    if (_preSelectedTechId != null) {
      final techs = ref.read(techniciansProvider).valueOrNull ?? [];
      tech = techs.where((t) => t.id == _preSelectedTechId).firstOrNull;
    }

    final width = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface2,
        insetPadding: EdgeInsets.symmetric(horizontal: width > 600 ? (width - 500) / 2 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text('تم استلام طلبك بنجاح!', style: AppTextStyles.headlineMed),
            const SizedBox(height: 24),
            if (tech != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.gold.withValues(alpha: 0.2))),
                child: Row(
                  children: [
                    CircleAvatar(radius: 25, backgroundColor: AppColors.surface2, child: Text(tech.spec.icon, style: const TextStyle(fontSize: 24))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الفني المختار:', style: AppTextStyles.labelMed),
                          Text(tech.name, style: AppTextStyles.titleMed),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('كود التتبع الخاص بك:', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: result.trackingCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gold.withValues(alpha: 0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(result.trackingCode, style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold, fontSize: 24, letterSpacing: 2)),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy, size: 18, color: AppColors.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(tech != null ? 'الفني سيتواصل معك قريباً لتأكيد الموعد.' : 'سنقوم بتعيين أفضل فني متاح والتواصل معك عبر الواتساب.', textAlign: TextAlign.center, style: AppTextStyles.bodyMed),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.go('/'), child: const Text('الرئيسية')),
          AppButton(label: 'تتبع الطلب', size: ButtonSize.sm, onTap: () => context.go('/track/${result.trackingCode}')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width > 900 ? (width - 800) / 2 : AppSpacing.xl;

    return Scaffold(
      appBar: AppBar(title: const Text('طلب خدمة منزلية'), centerTitle: width < 900),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepHeader('1', 'تأكيد نوع الخدمة'),
              const SizedBox(height: AppSpacing.lg),
              _buildServiceGrid(width),
              const SizedBox(height: AppSpacing.xxxl),
              _buildStepHeader('2', 'بيانات التواصل والعنوان'),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    AppTextField(label: 'الاسم', controller: _nameController, prefixIcon: Icons.person_outline, validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(label: 'رقم الهاتف (واتساب)', controller: _phoneController, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_android, validator: (v) => v!.length < 11 ? 'رقم غير صحيح' : null),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(label: 'العنوان بالتفصيل', controller: _areaController, prefixIcon: Icons.location_on_outlined, validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(label: 'وصف المشكلة', controller: _descriptionController, hint: 'اشرح لنا المشكلة باختصار لنرسل الفني المناسب', maxLines: 3),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AppButton(label: 'تأكيد طلب الخدمة', onTap: _submit, isLoading: _isLoading, icon: Icons.send_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String step, String title) {
    return Row(
      children: [
        Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle), child: Center(child: Text(step, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.headlineMed),
      ],
    );
  }

  Widget _buildServiceGrid(double width) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 600 ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 60,
      ),
      itemCount: ServiceType.values.length,
      itemBuilder: (context, index) {
        final type = ServiceType.values[index];
        final isSelected = _selectedService == type;
        final isEnabled = _preSelectedTechId == null;
        
        return InkWell(
          onTap: isEnabled ? () => setState(() => _selectedService = type) : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: !isEnabled && !isSelected ? 0.5 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? AppColors.gold : AppColors.borderDefault, width: 2),
              ),
              child: Row(
                children: [
                  Text(type.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(type.label, style: AppTextStyles.titleMed.copyWith(color: isSelected ? AppColors.gold : AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
