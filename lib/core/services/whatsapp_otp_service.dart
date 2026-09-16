import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../features/admin/domain/models/order.dart';
import '../../features/admin/domain/models/technician.dart';

class WhatsAppOtpService {
  static const String instanceId = 'instance188485';
  static const String token = '2f92w8s3fow0ofku';

  static String _cleanPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = '2$cleanPhone';
    if (!cleanPhone.startsWith('2')) cleanPhone = '20$cleanPhone';
    return cleanPhone;
  }

  static String generateOtp() {
    return (1000 + Random().nextInt(9000)).toString();
  }

  /// إرسال الكود في الخلفية عبر UltraMsg API
  static Future<bool> sendOtpViaWhatsApp(String phone, String otp) async {
    final cleanPhone = _cleanPhoneNumber(phone);
    final message = 'كود التحقق الخاص بك لمنصة حرفي هو: *$otp*\n\nيرجى إدخال الكود في التطبيق لإتمام طلبك. 🛠️';
    return await _sendMessage(to: cleanPhone, body: message);
  }

  /// إرسال رسالة تأكيد للعميل فور نجاح الطلب
  static Future<bool> sendOrderConfirmationToClient(Order order) async {
    final cleanPhone = _cleanPhoneNumber(order.clientPhone);
    final message = '''
مرحباً ${order.clientName} 👋
تم استلام طلبك لخدمة (*${order.service.label}*) بنجاح! 🛠️

📌 كود التتبع الخاص بك: *${order.trackingCode}*
📍 العنوان: ${order.area}
🛡️ *طلبك محمّي بضمان صيانة مجاني لمدة 30 يوم ضد أي عيوب تصليح.*

يمكنك متابعة حالة طلبك مباشرة عبر التطبيق باستخدام كود التتبع.
شكراً لثقتك بـ *منصة حرفي* ✨
''';
    return await _sendMessage(to: cleanPhone, body: message);
  }

  /// إرسال إشعار للفني فور تعيين طلب جديد له
  static Future<bool> sendTechAssignmentNotification({
    required Technician tech,
    required Order order,
  }) async {
    if (tech.phone.isEmpty) return false;
    final cleanPhone = _cleanPhoneNumber(tech.phone);
    final message = '''
مرحباً كابتن ${tech.name} 🛠️
تم تعيين طلب جديد لك في منصة حرفي!

📋 الخدمة: *${order.service.label}*
👤 اسم العميل: ${order.clientName}
📞 رقم الهاتف: ${order.clientPhone}
📍 العنوان: ${order.area}
${order.description != null && order.description!.trim().isNotEmpty ? '📝 الوصف: ${order.description}\n' : ''}📌 كود الطلب: *${order.trackingCode}*

يرجى التواصل مع العميل لمتابعة الموعد والتفاصيل. 👍
''';
    return await _sendMessage(to: cleanPhone, body: message);
  }

  /// إرسال إشعار للعميل عند اعتذار/رفض الفني للطلب
  static Future<bool> sendOrderRejectionNotificationToClient({
    required Order order,
    String? reason,
  }) async {
    if (order.clientPhone.isEmpty) return false;
    final cleanPhone = _cleanPhoneNumber(order.clientPhone);
    final reasonText = (reason != null && reason.trim().isNotEmpty)
        ? 'سبب الاعتذار: *$reason*\n'
        : '';
    final message = '''
مرحباً ${order.clientName} 👋
نحيطك علماً بأن الفني اعتذر عن قبول طلبك رقم: *${order.trackingCode}* (خدمة *${order.service.label}*). 🛠️

$reasonText
يمكنك اختيار فني آخر أو تقديم طلب جديد عبر التطبيق فوراً. ✨
''';
    return await _sendMessage(to: cleanPhone, body: message);
  }

  static Future<bool> _sendMessage({required String to, required String body}) async {
    try {
      final url = Uri.parse('https://api.ultramsg.com/$instanceId/messages/chat');
      final response = await http.post(url, body: {
        'token': token,
        'to': to,
        'body': body,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('WhatsApp API Error: $e');
      return false;
    }
  }

  static Future<bool> showOtpVerificationDialog({
    required BuildContext context,
    required String phone,
    required String generatedOtp,
  }) async {
    bool verified = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _OtpDialogContent(
        phone: phone,
        initialOtp: generatedOtp,
        onVerified: () {
          verified = true;
          Navigator.pop(context);
        },
      ),
    );

    return verified;
  }
}

class _OtpDialogContent extends StatefulWidget {
  final String phone;
  final String initialOtp;
  final VoidCallback onVerified;

  const _OtpDialogContent({
    required this.phone,
    required this.initialOtp,
    required this.onVerified,
  });

  @override
  State<_OtpDialogContent> createState() => _OtpDialogContentState();
}

class _OtpDialogContentState extends State<_OtpDialogContent> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late String _currentOtp;
  
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.initialOtp;
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isResending) return;
    setState(() => _isResending = true);

    final newOtp = WhatsAppOtpService.generateOtp();
    final sent = await WhatsAppOtpService.sendOtpViaWhatsApp(widget.phone, newOtp);

    if (mounted) {
      setState(() => _isResending = false);
      if (sent) {
        _currentOtp = newOtp;
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إعادة إرسال الكود إلى رقم الواتساب بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إعادة إرسال الكود، يرجى المحاولة لاحقاً')),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.mark_email_read_outlined, color: AppColors.gold, size: 64),
          const SizedBox(height: 24),
          Text('التحقق من الرقم', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'أدخل الكود المرسل إلى رقم الواتساب الخاص بك\n${widget.phone}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => SizedBox(
                width: 65,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: AppColors.surface1,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.gold, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 3) _focusNodes[index + 1].requestFocus();
                    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
                    
                    if (_controllers.every((c) => c.text.isNotEmpty)) {
                      String entered = _controllers.map((c) => c.text).join();
                      if (entered == _currentOtp) {
                        widget.onVerified();
                      }
                    }
                  },
                ),
              )),
            ),
          ),

          const SizedBox(height: 20),

          // زر وعداد إعادة إرسال الكود
          _isResending
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                )
              : TextButton.icon(
                  onPressed: _secondsRemaining == 0 ? _resendCode : null,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _secondsRemaining > 0
                        ? 'إعادة إرسال الكود خلال $_secondsRemaining ثانية'
                        : 'إعادة إرسال الكود الآن',
                    style: TextStyle(
                      color: _secondsRemaining == 0 ? AppColors.gold : AppColors.textMuted,
                      fontWeight: _secondsRemaining == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),

          const Spacer(),
          AppButton(
            label: 'تأكيد الرمز',
            onTap: () {
              String entered = _controllers.map((c) => c.text).join();
              if (entered == _currentOtp) {
                widget.onVerified();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الكود غير صحيح، حاول مرة أخرى')),
                );
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تغيير الرقم أو إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
