import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/whatsapp_otp_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';
import '../../../admin/domain/models/promo_code.dart';
import '../../../admin/presentation/providers/promo_codes_provider.dart';
import '../providers/client_screen_providers.dart';

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
  final _promoCodeController = TextEditingController();
  PromoCode? _appliedPromo;
  bool _isValidatingPromo = false;
  String? _promoError;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  String _preferredTimeSlot = '9:00 ص - 12:00 ظ';
  String? _preSelectedTechId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSavedClientData();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  Future<void> _loadSavedClientData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('client_phone') ?? '';
      _nameController.text = prefs.getString('client_name') ?? '';
      _phoneController.text = savedPhone;

      // مزامنة الرقم الموثق سابقاً لتفادي طلب OTP مجدداً
      final verifiedPhone = prefs.getString('verified_phone');
      if (savedPhone.isNotEmpty && (verifiedPhone == null || verifiedPhone.isEmpty)) {
        await prefs.setString('verified_phone', savedPhone);
        await prefs.setBool('is_client_verified', true);
      }
      
      // مزامنة الموقع المختار في الهوم مع شاشة الطلب
      final savedArea = prefs.getString('client_area');
      if (savedArea != null && savedArea.isNotEmpty) {
        _areaController.text = savedArea;
      } else {
        // لو مفيش عنوان محفوظ، نسحب الموقع المختار حالياً من الـ provider
        final currentLocation = ref.read(userLocationProvider);
        _areaController.text = currentLocation.fullLocation;
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is ServiceType) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(requestSelectedServiceProvider.notifier).state = extra;
        });
      } else if (extra is Map<String, dynamic>) {
        final service = extra['service'] as ServiceType?;
        final description = extra['description'] as String?;
        _preSelectedTechId = extra['techId'] as String?;
        
        if (service != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(requestSelectedServiceProvider.notifier).state = service;
          });
        }
        if (description != null) {
          _descriptionController.text = description;
        }
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
    final selectedService = ref.read(requestSelectedServiceProvider);
    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار نوع الخدمة')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_preSelectedTechId != null) {
      final techs = ref.read(techniciansProvider).valueOrNull ?? [];
      final tech = techs.where((t) => t.id == _preSelectedTechId).firstOrNull;
      
      if (tech == null || !tech.canAcceptOrders) {
        _showTechUnavailableDialog();
        return;
      }
    }

    final phone = _phoneController.text.trim();
    ref.read(requestLoadingProvider.notifier).state = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('client_name', _nameController.text.trim());
      await prefs.setString('client_phone', phone);
      await prefs.setString('client_area', _areaController.text.trim());

      final normalizedInputPhone = _normalizePhone(phone);
      final normalizedVerifiedPhone = _normalizePhone(prefs.getString('verified_phone') ?? prefs.getString('client_phone') ?? '');
      
      final isAlreadyVerified = normalizedInputPhone.isNotEmpty &&
          (normalizedVerifiedPhone == normalizedInputPhone || prefs.getBool('is_client_verified') == true);

      if (!isAlreadyVerified) {
        final otp = WhatsAppOtpService.generateOtp();
        await WhatsAppOtpService.sendOtpViaWhatsApp(phone, otp);
        if (!mounted) return;
        final isVerified = await WhatsAppOtpService.showOtpVerificationDialog(
          context: context, 
          phone: phone, 
          generatedOtp: otp,
        );
        if (!isVerified) {
          ref.read(requestLoadingProvider.notifier).state = false;
          return;
        }
        await prefs.setString('verified_phone', phone);
        await prefs.setBool('is_client_verified', true);
      }

      final discountAmount = _appliedPromo != null ? _appliedPromo!.calculateDiscount(100) : 0;
      final order = Order(
        id: '', trackingCode: '',
        clientName: _nameController.text.trim(),
        clientPhone: phone,
        service: selectedService,
        area: _areaController.text.trim(),
        description: _descriptionController.text.trim(),
        techId: _preSelectedTechId,
        status: _preSelectedTechId != null ? OrderStatus.assigned : OrderStatus.pending,
        promoCode: _appliedPromo?.code,
        discountAmount: discountAmount,
        isScheduled: _isScheduled,
        scheduledDate: _isScheduled ? (_scheduledDate ?? DateTime.now().add(const Duration(days: 1))) : null,
        preferredTimeSlot: _isScheduled ? _preferredTimeSlot : null,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );

      final result = await ref.read(adminActionsProvider).createOrder(order);
      result.when(
        left: (f) => AppErrorHandler.showSnackBar(context, f.message),
        right: (createdOrder) {
          if (_appliedPromo != null) {
            incrementPromoCodeUse(_appliedPromo!.code);
          }
          WhatsAppOtpService.sendOrderConfirmationToClient(createdOrder);
          if (mounted) _showSuccessDialog(createdOrder);
        },
      );
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) ref.read(requestLoadingProvider.notifier).state = false;
    }
  }

  void _showTechUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('الفني غير متاح حالياً ⚠️'),
        content: const Text('عذراً، الفني الذي اخترته لم يعد متاحاً لاستقبال طلبات في هذه اللحظة. يمكنك إرسال الطلب كـ "طلب عام" وسيقوم أفضل فني متاح في منطقتك بالتواصل معك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع لتغيير الفني'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _preSelectedTechId = null);
              Navigator.pop(context);
            },
            child: const Text('إرسال كطلب عام'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Order result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 70),
            const SizedBox(height: 16),
            Text('تم طلب الخدمة بنجاح!', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 12),
            Text('كود التتبع: ${result.trackingCode}', style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
            const SizedBox(height: 24),
            AppButton(label: 'تتبع الطلب', onTap: () => context.go('/track/${result.trackingCode}')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final selectedService = ref.watch(requestSelectedServiceProvider);
    final isLoading = ref.watch(requestLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('طلب خدمة منزلية'), backgroundColor: Colors.transparent),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrganicBanner(),
                  const SizedBox(height: 24),

                  _buildStepHeader('1', 'تأكيد نوع الخدمة'),
                  const SizedBox(height: 16),
                  _buildOrganicServiceGrid(width),

                  if (selectedService != null) ...[
                    const SizedBox(height: 32),
                    _buildStepHeader('👤', _preSelectedTechId == null ? 'الفنيين المقترحين' : 'الفني المختار'),
                    const SizedBox(height: 16),
                    _buildAvailableTechsList(selectedService),
                  ],

                  const SizedBox(height: 24),
                  _buildStepHeader('🕒', 'موعد تقديم الخدمة'),
                  const SizedBox(height: 16),
                  _buildSchedulingSection(),

                  const SizedBox(height: 32),
                  _buildStepHeader('2', 'بيانات التواصل والعنوان'),
                  const SizedBox(height: 16),
                  _buildContactForm(),

                  const SizedBox(height: 24),
                  _buildStepHeader('🎁', 'كوبون الخصم (البرومو كود)'),
                  const SizedBox(height: 16),
                  _buildPromoCodeSection(),

                  const SizedBox(height: 40),
                  AppButton(
                    label: 'تأكيد وإرسال الطلب',
                    onTap: _submit,
                    isLoading: isLoading,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganicBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلبك محمي بضمان حرفي لمدة شهر 🛡️', style: AppTextStyles.titleMed.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                Text('تأكيد الخدمة من التطبيق يُفعّل لك الضمان تلقائياً.', style: AppTextStyles.labelMed.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(step, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.headlineMed.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildOrganicServiceGrid(double width) {
    final selectedService = ref.watch(requestSelectedServiceProvider);
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ServiceType.values.length,
        itemBuilder: (context, index) {
          final type = ServiceType.values[index];
          final isSelected = selectedService == type;
          return Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SizedBox(
              width: 120,
              child: _OrganicServiceItem(
                type: type,
                isSelected: isSelected,
                onTap: () {
                  ref.read(requestSelectedServiceProvider.notifier).state = type;
                  setState(() => _preSelectedTechId = null);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailableTechsList(ServiceType service) {
    if (_preSelectedTechId != null) return _buildSelectedTechCard();

    final techsAsync = ref.watch(techniciansProvider);

    return techsAsync.when(
      skipLoadingOnRefresh: true,
      data: (techs) {
        final filtered = techs.where((t) => t.spec == service && t.canAcceptOrders).toList();
        
        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(16)),
            child: Text('سيتم تعيين أفضل فني متاح لك فور إرسال الطلب.', style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted)),
          );
        }
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filtered.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) => _TechOrganicMiniCard(
              tech: filtered[index],
              onSelect: () => setState(() => _preSelectedTechId = filtered[index].id),
            ),
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSelectedTechCard() {
    final tech = ref.watch(techniciansProvider).valueOrNull?.firstWhere((t) => t.id == _preSelectedTechId, orElse: () => throw Exception('Not found'));
    if (tech == null) return const SizedBox.shrink();

    final bool isEligible = tech.canAcceptOrders;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEligible ? AppColors.gold.withOpacity(0.08) : AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isEligible ? AppColors.gold.withOpacity(0.2) : AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surface3,
                backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                child: tech.photoUrl == null ? Text(tech.spec.icon) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tech.name, style: AppTextStyles.titleLarge),
                  Text(isEligible ? tech.rank : 'غير متاح حالياً', style: AppTextStyles.labelMed.copyWith(color: isEligible ? AppColors.gold : AppColors.error)),
                ]),
              ),
              TextButton(
                onPressed: () => setState(() => _preSelectedTechId = null),
                child: const Text('تغيير الفني', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (!isEligible)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ هذا الفني غير متاح لاستلام طلبات الآن، سيتم تحويل طلبك لطلب عام.',
                style: AppTextStyles.labelMed.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          AppTextField(label: 'الاسم بالكامل', controller: _nameController, prefixIcon: Icons.person_outline, validator: (v) => v!.isEmpty ? 'يرجى إدخل الاسم' : null),
          const SizedBox(height: 16),
          AppTextField(label: 'رقم الواتساب', controller: _phoneController, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_android_rounded, validator: (v) => v!.length < 11 ? 'رقم غير صحيح' : null),
          const SizedBox(height: 16),
          AppTextField(label: 'العنوان (المنطقة والشارع)', controller: _areaController, prefixIcon: Icons.location_on_outlined, validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null),
          const SizedBox(height: 16),
          AppTextField(label: 'وصف العطل باختصار', controller: _descriptionController, hint: 'مثال: حنفية المطبخ بتسرب ميه', maxLines: 2),
        ],
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingPromo = true;
      _promoError = null;
    });

    try {
      final promo = await validateAndFetchPromoCode(code);
      if (promo == null) {
        setState(() {
          _appliedPromo = null;
          _promoError = 'كود الخصم غير صحيح أو انتهت صلاحيته ❌';
        });
      } else {
        setState(() {
          _appliedPromo = promo;
          _promoError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تطبيق كود الخصم (${promo.code}) بنجاح! 🎉')),
        );
      }
    } catch (_) {
      setState(() => _promoError = 'خطأ في فحص الكود');
    } finally {
      setState(() => _isValidatingPromo = false);
    }
  }

  Widget _buildPromoCodeSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _appliedPromo != null ? AppColors.success : AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'أدخل كود الخصم (مثال: HARAFY10)',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined, color: AppColors.gold),
                    errorText: _promoError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onPressed: _isValidatingPromo ? null : _applyPromoCode,
                child: _isValidatingPromo
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('تطبيق الخصم', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_appliedPromo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'كود خصم مفعّل: ${_appliedPromo!.code} (${_appliedPromo!.discountPercentage > 0 ? "خصم ${_appliedPromo!.discountPercentage}%" : "خصم ${_appliedPromo!.discountAmount} ج.م"}) 🎉',
                    style: AppTextStyles.labelMed.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchedulingSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('خدمة فورية الآن ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: !_isScheduled,
                  onSelected: (val) => setState(() => _isScheduled = !val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('حجز موعد 📅', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _isScheduled,
                  onSelected: (val) => setState(() => _isScheduled = val),
                ),
              ),
            ],
          ),
          if (_isScheduled) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _scheduledDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _scheduledDate != null
                              ? 'الموعد المحدد: ${intl.DateFormat('d MMMM yyyy').format(_scheduledDate!)}'
                              : 'اختر تاريخ الزيارة المناسب 📅',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('الفترة الزمنية المفضلة:', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                '9:00 ص - 12:00 ظ',
                '1:00 ظ - 4:00 ع',
                '5:00 م - 8:00 م',
                '8:00 م - 11:00 م',
              ].map((slot) => ChoiceChip(
                label: Text(slot),
                selected: _preferredTimeSlot == slot,
                onSelected: (val) {
                  if (val) setState(() => _preferredTimeSlot = slot);
                },
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrganicServiceItem extends StatelessWidget {
  final ServiceType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrganicServiceItem({required this.type, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.05), width: 2),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.gold.withOpacity(0.2), blurRadius: 10)] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/${_getAsset(type)}', fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: AppColors.surface2)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(isSelected ? 0.4 : 0.7)],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(type.label, style: AppTextStyles.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              if (isSelected) const Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: AppColors.gold, size: 20)),
            ],
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

class _TechOrganicMiniCard extends StatelessWidget {
  final Technician tech;
  final VoidCallback onSelect;

  const _TechOrganicMiniCard({required this.tech, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.surface3,
                  backgroundImage: tech.photoUrl != null ? NetworkImage(tech.photoUrl!) : null,
                  child: tech.photoUrl == null ? Text(tech.spec.icon) : null,
                ),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: AppColors.gold, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tech.name.split(' ').first, style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tech.rating.toStringAsFixed(1), style: AppTextStyles.labelMed),
                const Icon(Icons.star, color: AppColors.gold, size: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
