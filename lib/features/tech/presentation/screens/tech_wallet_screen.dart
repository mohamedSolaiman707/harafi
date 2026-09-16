import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/presentation/providers/wallet_recharges_provider.dart';
import '../../../admin/domain/enums/order_status.dart';

class TechWalletScreen extends ConsumerWidget {
  const TechWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techAsync = ref.watch(currentTechnicianProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('محفظتي 💳'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: techAsync.when(
        data: (tech) {
          if (tech == null) {
            return const Center(child: Text('عذراً، لم يتم العثور على بيانات الفني ⚠️'));
          }

          final ordersAsync = ref.watch(techOrdersStreamProvider(tech.id));
          final completedOrders = ordersAsync.valueOrNull
                  ?.where((o) => o.status == OrderStatus.completed)
                  .toList() ??
              [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── كارت رصيد المحفظة الرئيسي ───
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        gradient: AppGradients.goldButton,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: AppShadows.goldGlow,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 48,
                            color: Color(0xFF090D16),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'الرصيد المتاح للمشاوير والطلبات',
                            style: TextStyle(
                              color: Color(0xFF090D16),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${tech.walletBalance} ج.م',
                            style: const TextStyle(
                              color: Color(0xFF090D16),
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090D16).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tech.walletBalance >= AppConstants.platformFee
                                  ? 'محفظتك مشحونة وجاهزة لاستقبال الطلبات 🟢'
                                  : 'رصيد محفظتك منخفض! يرجى الشحن ⚠️',
                              style: const TextStyle(
                                color: Color(0xFF090D16),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ─── كارت الشحن الأوتوماتيكي المزدوج ───
                    AppCard(
                      color: AppColors.surface1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, color: AppColors.gold, size: 26),
                              const SizedBox(width: 8),
                              Text(
                                'شحن الرصيد الأوتوماتيكي ⚡',
                                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'اختر طريقة الشحن المناسبة لك (شحن محفظة مباشر أو كود دفع فوري من أي كشك/سايبر):',
                            style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'شحن أوتوماتيكي الآن 💳',
                                  icon: Icons.add_card_rounded,
                                  onTap: () => _showRechargeSubmissionSheet(context, ref, tech),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const CircleAvatar(
                                  backgroundColor: AppColors.surface2,
                                  child: Icon(Icons.chat_rounded, color: AppColors.success, size: 20),
                                ),
                                tooltip: 'تواصل عبر واتساب',
                                onPressed: () {
                                  final message = 'السلام عليكم، أنا الفني ${tech.name} (رقم الهاتف: ${tech.phone})، أود الاستفسار عن شحن محفظتي في منصة حرفي. 💳';
                                  final uri = WhatsAppUtils.buildUri('201014250577', message);
                                  launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                    _RechargesHistorySection(techId: tech.id),
                    const SizedBox(height: AppSpacing.xxl),

                    Text(
                      'سجل العمليات والخصومات 📋',
                      style: AppTextStyles.headlineMed.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // كارت الهدية الترحيبية
                    AppCard(
                      color: AppColors.surface1,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.success, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'رصيد ترحيبي عند انضمامك لـ حرفي 🎉',
                                  style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'هدية ترحيبية مجانية لبدء مشاويرك',
                                  style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+100 ج.م',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    if (completedOrders.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'لا توجد عمليات خصم سابقة، ستظهر خصومات الـ ${AppConstants.platformFee} ج.م الرمزية فور إكمال أول طلب.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: completedOrders.length,
                        itemBuilder: (context, index) {
                          final order = completedOrders[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: AppCard(
                              color: AppColors.surface1,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'رسم منصة رمزي لطلب (${order.service.label})',
                                          style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'كود الطلب: #${order.trackingCode} • العميل: ${order.clientName}',
                                          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '-${AppConstants.platformFee} ج.م',
                                    style: AppTextStyles.titleLarge.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => AppErrorWidget(
          message: AppErrorHandler.translate(e),
          error: e,
          onRetry: () => ref.invalidate(currentTechnicianProvider),
        ),
      ),
    );
  }

  void _showRechargeSubmissionSheet(BuildContext context, WidgetRef ref, Technician tech) {
    final width = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 600 : width),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (context) => _DualRechargeSubmissionSheet(tech: tech),
    );
  }
}

// ─── Recharges History Section ──────────────────────────────────────────────────

class _RechargesHistorySection extends ConsumerWidget {
  final String techId;
  const _RechargesHistorySection({required this.techId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rechargesAsync = ref.watch(techWalletRechargesStreamProvider(techId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل طلبات الشحن 💳',
          style: AppTextStyles.headlineMed.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        rechargesAsync.when(
          data: (recharges) {
            if (recharges.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Center(
                  child: Text('لا توجد طلبات شحن سابقة مسجلة بالمنصة ℹ️', style: TextStyle(color: AppColors.textMuted)),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recharges.length,
              itemBuilder: (context, index) {
                final item = recharges[index];
                Color statusColor = AppColors.gold;
                String statusLabel = 'قيد المراجعة ⏱️';
                if (item.isApproved || item.isAutoProcessed) {
                  statusColor = AppColors.success;
                  statusLabel = 'تم الشحن أوتوماتيكياً 🟢';
                } else if (item.isRejected) {
                  statusColor = AppColors.error;
                  statusLabel = 'مرفوض 🔴';
                }

                final bool isFawry = item.isFawry;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppColors.surface1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Icon(
                        isFawry ? Icons.qr_code_2_rounded : Icons.phone_android_rounded,
                        color: statusColor,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text('شحن ${item.amount} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFawry ? Colors.orange.withValues(alpha: 0.2) : AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFawry ? 'فوري 🟢' : 'فودافون كاش 📱',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isFawry ? Colors.orange : AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isFawry && item.fawryRefCode != null
                          ? 'كود فوري: ${item.fawryRefCode} • ${intl.DateFormat('d MMM, HH:mm').format(item.createdAt)}'
                          : 'المحول: ${item.senderPhone} • ${intl.DateFormat('d MMM, HH:mm').format(item.createdAt)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, s) => Text('تعذر تحميل طلبات الشحن: ${e.toString()}'),
        ),
      ],
    );
  }
}

// ─── Dual Recharge Submission Sheet (Method 1: Vodafone Cash vs Method 2: Fawry Pay) ───

class _DualRechargeSubmissionSheet extends ConsumerStatefulWidget {
  final Technician tech;
  const _DualRechargeSubmissionSheet({required this.tech});

  @override
  ConsumerState<_DualRechargeSubmissionSheet> createState() => _DualRechargeSubmissionSheetState();
}

class _DualRechargeSubmissionSheetState extends ConsumerState<_DualRechargeSubmissionSheet> {
  int _selectedMethod = 0; // 0 = Vodafone Cash Auto-Match, 1 = Fawry Pay Code
  final _amountController = TextEditingController(text: '100');
  late final TextEditingController _senderPhoneController;
  XFile? _receiptImage;
  bool _isLoading = false;
  String? _generatedFawryCode;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _senderPhoneController = TextEditingController(text: widget.tech.phone);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image != null) {
      setState(() => _receiptImage = image);
    }
  }

  String _generateRandomFawryCode() {
    final rnd = Random();
    final c1 = rnd.nextInt(900) + 100;
    final c2 = rnd.nextInt(900) + 100;
    final c3 = rnd.nextInt(900) + 100;
    return '$c1$c2$c3';
  }

  Future<void> _submitVodafoneCash() async {
    final amount = int.tryParse(_amountController.text.trim());
    final senderPhone = _senderPhoneController.text.trim();

    if (amount == null || amount <= 0 || senderPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ الشحن ورقم محفظة المحول')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String receiptUrl = '';
      if (_receiptImage != null) {
        final storageService = StorageService();
        final String fileName = 'recharge_${widget.tech.id}_${DateTime.now().millisecondsSinceEpoch}';
        final String? uploadedUrl = await storageService.uploadImage(
          image: _receiptImage!,
          path: 'tech_photos',
          fileName: fileName,
        );
        receiptUrl = uploadedUrl ?? '';
      }

      final rechargeData = {
        'tech_id': widget.tech.id,
        'tech_name': widget.tech.name,
        'tech_phone': widget.tech.phone,
        'amount': amount,
        'sender_phone': senderPhone,
        'receipt_url': receiptUrl,
        'status': 'pending',
        'payment_method': 'vodafone_cash',
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('wallet_recharges').insert(rechargeData);
      ref.invalidate(techWalletRechargesStreamProvider(widget.tech.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ تم تسجيل طلب الشحن! سيتم ربط الرصيد أوتوماتيكياً فور وصول الرسالة النصية خلال ثوانٍ.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateFawryPayCode() async {
    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ الشحن المراد سداده في فوري')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final code = _generateRandomFawryCode();
      final rechargeData = {
        'tech_id': widget.tech.id,
        'tech_name': widget.tech.name,
        'tech_phone': widget.tech.phone,
        'amount': amount,
        'sender_phone': widget.tech.phone,
        'receipt_url': '',
        'status': 'pending',
        'payment_method': 'fawry',
        'fawry_ref_code': code,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('wallet_recharges').insert(rechargeData);
      ref.invalidate(techWalletRechargesStreamProvider(widget.tech.id));

      if (mounted) {
        setState(() {
          _generatedFawryCode = code;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSnackBar(context, e);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إعادة شحن المحفظة 💳', style: AppTextStyles.headlineMed),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Dual Method Selector Tabs ───
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedMethod = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedMethod == 0 ? AppColors.gold : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '📱 فودافون كاش (مباشر)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedMethod == 0 ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedMethod = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedMethod == 1 ? AppColors.gold : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🟢 كود فوري (للسنترال)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedMethod == 1 ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedMethod == 0) ...[
              // ─── Method 0: Vodafone Cash Direct Auto-Match ───
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مبلغ الشحن (ج.م)',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  suffixText: 'ج.م',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _senderPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم محفظتك (التي ستُحول منها)',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.success, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'شحن أوتوماتيكي سريع: يتم مطابقة التحويل وإضافة الرصيد فوراً بـ 5 ثوانٍ عند إرسال المبلغ لرقم 01014250577.',
                        style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickReceipt,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _receiptImage != null ? AppColors.success : AppColors.borderDefault),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _receiptImage != null ? Icons.check_circle : Icons.receipt_outlined,
                        color: _receiptImage != null ? AppColors.success : AppColors.gold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _receiptImage != null ? 'تم اختيار صورة الإيصال ✅' : 'رفع صورة إيصال / سكرين شوت (اختياري)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.upload_file, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'تأكيد التحويل المباشر ⚡',
                onTap: _submitVodafoneCash,
                isLoading: _isLoading,
                icon: Icons.send_rounded,
              ),
            ] else ...[
              // ─── Method 1: Fawry Pay Code Generator ───
              if (_generatedFawryCode == null) ...[
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'مبلغ الشحن المطلوب (ج.م)',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                    suffixText: 'ج.م',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.storefront_rounded, color: Colors.orange, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'مثالي للشحن من أي كشك أو سايبر: يُولّد كود فوري مخصص تدفعه في أي مكان وسينزل الرصيد في حسابه أوتوماتيكياً.',
                          style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'إنشاء كود دفع فوري 🟢',
                  onTap: _generateFawryPayCode,
                  isLoading: _isLoading,
                  icon: Icons.qr_code_2_rounded,
                ),
              ] else ...[
                // ─── Digital Fawry Payment Kiosk Card ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.15), blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_rounded, color: AppColors.gold, size: 22),
                          SizedBox(width: 8),
                          Text('كود دفع فوري (Fawry Pay Code)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_generatedFawryCode!.substring(0, 3)} ${_generatedFawryCode!.substring(3, 6)} ${_generatedFawryCode!.substring(6)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                              tooltip: 'نسخ الكود',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generatedFawryCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ كود دفع فوري للحافظة 📋')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'مبلغ الشحن: ${_amountController.text} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.borderSubtle),
                      const SizedBox(height: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('طريقة السداد في الكشك أو السايبر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gold)),
                          SizedBox(height: 6),
                          Text('1. توجه لأي سوبرماركت، سايبر، أو كشك به ماكينة فوري.', style: TextStyle(fontSize: 11)),
                          Text('2. اطلب السداد عبر خدمة (مدفوعات فوري كود).', style: TextStyle(fontSize: 11)),
                          Text('3. أعطه الرقم أعلاه وادفع المبلغ وسينزل الرصيد أوتوماتيكياً.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'تم، العودة للمحفظة',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
