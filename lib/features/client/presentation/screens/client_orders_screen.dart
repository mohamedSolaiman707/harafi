import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/whatsapp_otp_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/orders_provider.dart';

import '../providers/client_screen_providers.dart';

class ClientOrdersScreen extends ConsumerStatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  ConsumerState<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends ConsumerState<ClientOrdersScreen> {
  final _phoneController = TextEditingController();
  bool _isDeviceVerified = false;
  String? _verifiedPhone;
  bool _isSendingOtp = false;
  bool _showPhoneInput = false;

  @override
  void initState() {
    super.initState();
    _checkDeviceVerification();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  Future<void> _checkDeviceVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('verified_phone') ?? prefs.getString('client_phone') ?? '';

    if (savedPhone.isNotEmpty) {
      await prefs.setString('verified_phone', savedPhone);
      await prefs.setBool('is_client_verified', true);
      setState(() {
        _verifiedPhone = savedPhone;
        _phoneController.text = savedPhone;
        _isDeviceVerified = true;
        _showPhoneInput = false;
      });
      if (mounted) {
        ref.read(clientOrdersSearchPhoneProvider.notifier).state = savedPhone;
      }
    } else {
      setState(() {
        _showPhoneInput = true;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSearch() async {
    final inputPhone = _phoneController.text.trim();
    if (inputPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الهاتف أولاً')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('verified_phone') ?? prefs.getString('client_phone') ?? '';
    final normalizedInput = _normalizePhone(inputPhone);
    final normalizedSaved = _normalizePhone(savedPhone);

    // إذا كان الرقم المدخل هو نفس الرقم المحفوظ/الموثق مسبقاً على هذا الجهاز
    if (normalizedInput.isNotEmpty && normalizedInput == normalizedSaved) {
      await prefs.setString('verified_phone', inputPhone);
      await prefs.setBool('is_client_verified', true);
      setState(() {
        _verifiedPhone = inputPhone;
        _isDeviceVerified = true;
        _showPhoneInput = false;
      });
      ref.read(clientOrdersSearchPhoneProvider.notifier).state = inputPhone;
      return;
    }

    // إذا كان الرقم جديداً كلياً أو غير موثق على هذا الجهاز، يلزم إرسال OTP للتوثيق
    setState(() => _isSendingOtp = true);
    try {
      final otp = WhatsAppOtpService.generateOtp();
      await WhatsAppOtpService.sendOtpViaWhatsApp(inputPhone, otp);

      if (!mounted) return;
      
      // حتى لو واجه سيرفر الواتساب الخارجي عطلاً مؤقتاً، نفتح النافذة لإتاحة التجربة والتوثيق
      final isVerified = await WhatsAppOtpService.showOtpVerificationDialog(
        context: context,
        phone: inputPhone,
        generatedOtp: otp,
      );

      if (isVerified) {
        await prefs.setString('verified_phone', inputPhone);
        await prefs.setString('client_phone', inputPhone);
        await prefs.setBool('is_client_verified', true);

        if (mounted) {
          setState(() {
            _verifiedPhone = inputPhone;
            _isDeviceVerified = true;
            _showPhoneInput = false;
          });
          ref.read(clientOrdersSearchPhoneProvider.notifier).state = inputPhone;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم توثيق ملكية الرقم بنجاح وفتح سجل الطلبات 🔒✨')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم التوثيق، لا يمكنك الوصول لسجل طلبات رقم غير موثق 🛡️')),
          );
        }
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _switchAccount() {
    setState(() {
      _showPhoneInput = true;
      _phoneController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final submittedPhone = ref.watch(clientOrdersSearchPhoneProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل طلباتي'),
        centerTitle: !isDesktop,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          if (_isDeviceVerified && !_showPhoneInput && _verifiedPhone != null) ...[
                            // ─── الجهاز موثق مسبقاً ────────────────────────
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 44),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_verifiedPhone!, style: AppTextStyles.headlineLarge.copyWith(letterSpacing: 1.2)),
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'جهازك موثّق وآمن • يعرض طلباتك تلقائياً 🔒',
                              style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _switchAccount,
                              icon: const Icon(Icons.phonelink_setup_rounded, size: 16, color: AppColors.gold),
                              label: const Text('توثيق برقم آخر 🔄', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                            ),
                          ] else ...[
                            // ─── نموذج التوثيق بالرقم الجديد ──────────────
                            const Icon(Icons.security_rounded, color: AppColors.gold, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'حماية الخصوصية 🛡️',
                              style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'أدخل رقم هاتفك وسيصلك كود تحقق سريع عبر الواتساب لتوثيق الملكية وفتح سجل طلباتك الأمان.',
                              textAlign: TextAlign.center,
                              style: TextStyle(height: 1.5, color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppTextField(
                              label: 'رقم الهاتف',
                              hint: '01xxxxxxxxx',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_android,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppButton(
                              label: _isSendingOtp ? 'جاري إرسال رمز التحقق...' : 'توثيق وفتح السجل 🔒',
                              isLoading: _isSendingOtp,
                              onTap: _verifyAndSearch,
                              icon: Icons.shield_outlined,
                            ),
                            if (_isDeviceVerified && _verifiedPhone != null) ...[
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () => setState(() => _showPhoneInput = false),
                                child: const Text('إلغاء والعودة لرقمك الموثّق الحالي', style: TextStyle(color: AppColors.textMuted)),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                if (submittedPhone != null && !_showPhoneInput)
                  ref.watch(clientOrdersProvider(submittedPhone)).when(
                        data: (orders) => _OrdersList(orders: orders),
                        loading: () => const LoadingWidget(),
                        error: (e, s) => AppErrorWidget(
                          message: 'فشل جلب الطلبات',
                          error: e,
                          onRetry: () => ref.invalidate(clientOrdersProvider(submittedPhone)),
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

class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.assignment_late_outlined, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text('لم نجد أي طلبات مسجلة لهذا الرقم حتى الآن', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('سجل طلباتك (${orders.length})', style: AppTextStyles.headlineMed.copyWith(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: Text(
                'آخر التحديثات ⚡',
                style: AppTextStyles.labelMed.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.lg),
          itemBuilder: (context, index) {
            return _OrderCard(order: orders[index]);
          },
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = order.status == OrderStatus.completed;
    final String formattedDate = intl.DateFormat('d MMMM yyyy').format(order.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Top Header (Code & Status) ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2.withValues(alpha: 0.5),
                border: const Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.trackingCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ كود التتبع 📋')),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag, size: 13, color: AppColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            order.trackingCode,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.gold,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 12, color: AppColors.gold),
                        ],
                      ),
                    ),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
            ),

            // ─── Main Content ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // أيقونة الخدمة داخل كارت مميز
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.surface2, AppColors.surface3],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDefault),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(order.service.icon, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.service.label,
                          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 5),
                            Text(
                              formattedDate,
                              style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        if (order.isScheduled) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_available_rounded, size: 12, color: AppColors.gold),
                                const SizedBox(width: 4),
                                Text(
                                  'موعد مجدول ${order.preferredTimeSlot != null ? "• ${order.preferredTimeSlot}" : ""}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (order.finalPrice != null && order.finalPrice! > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${order.finalPrice} ج.م',
                        style: AppTextStyles.titleMed.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─── Footer Action Bar ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/track/${order.trackingCode}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.near_me_rounded, size: 16, color: AppColors.gold),
                            SizedBox(width: 6),
                            Text(
                              'تتبع الطلب الآن',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/request', extra: {'service': order.service, 'techId': order.techId}),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.gold, Color(0xFFB8860B)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_task_rounded, size: 16, color: Colors.black),
                              SizedBox(width: 6),
                              Text(
                                'طلب جديد',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case OrderStatus.pending:
        color = AppColors.gold;
        icon = Icons.hourglass_top_rounded;
        break;
      case OrderStatus.assigned:
        color = AppColors.info;
        icon = Icons.assignment_ind_rounded;
        break;
      case OrderStatus.onTheWay:
        color = Colors.orange;
        icon = Icons.directions_run_rounded;
        break;
      case OrderStatus.started:
        color = Colors.blue;
        icon = Icons.build_rounded;
        break;
      case OrderStatus.completed:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case OrderStatus.cancelled:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
