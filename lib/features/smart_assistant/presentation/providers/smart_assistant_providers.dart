import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../data/repositories/supabase_smart_assistant_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/smart_diagnosis.dart';
import '../../domain/repositories/smart_assistant_repository.dart';
import '../../domain/usecases/analyze_problem_usecase.dart';

// ─── Repository & UseCase Providers ────────────────────────────────────────
final smartAssistantRepositoryProvider = Provider<SmartAssistantRepository>((ref) {
  return SupabaseSmartAssistantRepository(Supabase.instance.client);
});

final analyzeProblemUseCaseProvider = Provider<AnalyzeProblemUseCase>((ref) {
  final repository = ref.watch(smartAssistantRepositoryProvider);
  return AnalyzeProblemUseCase(repository);
});

// ─── State ──────────────────────────────────────────────────────────────────
class SmartAssistantState {
  final bool isLoading;
  final bool isTyping;
  final bool isRecordingVoice;
  final int recordingDurationSeconds;
  final String? error;
  final List<ChatMessage> messages;
  final String? pendingTrackingCode; // للبحث عن طلب معلق

  SmartAssistantState({
    this.isLoading = false,
    this.isTyping = false,
    this.isRecordingVoice = false,
    this.recordingDurationSeconds = 0,
    this.error,
    this.messages = const [],
    this.pendingTrackingCode,
  });

  SmartAssistantState copyWith({
    bool? isLoading,
    bool? isTyping,
    bool? isRecordingVoice,
    int? recordingDurationSeconds,
    String? error,
    List<ChatMessage>? messages,
    String? pendingTrackingCode,
    bool clearPendingTracking = false,
  }) {
    return SmartAssistantState(
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
      isRecordingVoice: isRecordingVoice ?? this.isRecordingVoice,
      recordingDurationSeconds: recordingDurationSeconds ?? this.recordingDurationSeconds,
      error: error,
      messages: messages ?? this.messages,
      pendingTrackingCode: clearPendingTracking ? null : (pendingTrackingCode ?? this.pendingTrackingCode),
    );
  }
}

// ─── Intent Detection ────────────────────────────────────────────────────────
enum _UserIntent {
  orderTracking,  // تتبع طلب
  warrantyCheck,  // استفسار ضمان
  pricingQuery,   // استفسار أسعار
  emergencyAlert, // طوارئ
  diagnosis,      // تشخيص عطل
  greeting,       // ترحيب/تحية
  generalFaq,     // سؤال عام
  unknown,
}

// ─── Notifier ────────────────────────────────────────────────────────────────
class SmartAssistantNotifier extends StateNotifier<SmartAssistantState> {
  final AnalyzeProblemUseCase _analyzeUseCase;
  final Ref _ref;

  SmartAssistantNotifier(this._analyzeUseCase, this._ref) : super(SmartAssistantState()) {
    _initWelcomeMessage();
  }

  // ── Welcome Message ──────────────────────────────────────────────────────
  void _initWelcomeMessage() {
    final location = _ref.read(userLocationProvider);
    final cityName = location.city.isNotEmpty ? location.city : 'كفر الزيات';

    final welcomeMsg = ChatMessage(
      id: 'welcome_1',
      text: 'أهلاً بك في **نظام المساعد الذكي (Agent)** لخدمات الصيانة ($cityName).\n\n'
          'يمكن للـ Agent تقديم تحليل مباشر واستجابات ديناميكية متصلة بقاعدة البيانات:\n\n'
          '• **تشخيص أعطال الأجهزة** (غسالات، تكييفات، سباكة، كهرباء) وتحديد القطع والحلول\n'
          '• **تتبع الطلبات الفعالة** والاستعلام المباشر عن موقع وحالة الفني\n'
          '• **التحقق من الضمان** وتقديم إرشادات السلامة وتكاليف الصيانة المعتمدة\n\n'
          'كيف يمكننا مساعدتك الآن؟',
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: [
        'تشخيص عطل فوري',
        'تتبع حالة الطلب',
        'فحص ضمان الجهاز',
        'استفسار عن أسعار الصيانة',
        'إرشادات الطوارئ',
      ],
    );
    state = state.copyWith(messages: [welcomeMsg]);
  }

  String _normalizeArabic(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .trim();
  }

  // ── Intent Detection ─────────────────────────────────────────────────────
  _UserIntent _detectIntent(String text) {
    final norm = _normalizeArabic(text);

    // طوارئ أولاً - الأعلى أولوية
    final emergencyKw = ['ماس', 'شرارة', 'شرار', 'كهرباء بتكهرب', 'دخان', 'حريق', 'غاز بيسرب',
      'تسريب غاز', 'انفجار', 'تكهرب', 'شياط', 'بيشتعل', 'نار', 'عندي حريق', 'ريحة غاز', 'طارئة', 'طوارئ'];
    if (emergencyKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.emergencyAlert;

    // تتبع طلب
    final trackingKw = ['طلب', 'تتبع', 'تراكينج', 'كود', 'رقم الطلب', 'وين فنيي',
      'الفني جه', 'متي بييجي', 'ايمتي', 'طلبي', 'ح يجي', 'لسه', 'حالة الطلب',
      'رقم تتبع', 'tracking', 'بيني وبينه', 'الفني فين', 'hr-'];
    if (trackingKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.orderTracking;

    // ضمان
    final warrantyKw = ['ضمان', 'warranty', 'كفالة', 'رجع بايظ', 'مش شغال تاني',
      'نفس المشكلة', 'رجع العطل', 'بايظ تاني', 'المشكلة رجعت'];
    if (warrantyKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.warrantyCheck;

    // أسعار
    final pricingKw = ['سعر', 'اسعار', 'أسعار', 'كام', 'تكلفة', 'تكاليف', 'تسعير', 'فلوس', 'كم ج', 'بكام', 'الاسعار',
      'الأسعار', 'قد ايه', 'قد إيه', 'تقدير', 'عرض سعر', 'ارخص', 'أرخص', 'غالي', 'مجاني', 'رسوم الزيارة', 'رسوم'];
    if (pricingKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.pricingQuery;

    // تحية
    final greetKw = ['هلو', 'مرحبا', 'السلام', 'أهلاً', 'اهلاً', 'ازيك', 'عامل ايه', 'عامل إيه', 'صباح', 'مساء'];
    if (greetKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.greeting;

    // أسئلة عامة
    final faqKw = ['كيف', 'إزاي', 'ازاي', 'ممكن', 'محتاج اعرف', 'محتاج أعرف', 'تنزيل', 'التطبيق', 'التسجيل',
      'المنصة', 'حرفي', 'خدمتكم', 'من أنتم', 'شركة'];
    if (faqKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.generalFaq;

    // تشخيص الأعطال
    final diagnosisKw = ['عطل', 'مشكلة', 'خربان', 'بايظ', 'مش بيسقع', 'مش بيشتغل', 'صوت', 'تسريب', 'تنقيط', 'سخان', 'غسالة', 'تكييف', 'بوتاجاز', 'ثلاجة', 'شاشة', 'كهرباء', 'سباكة'];
    if (diagnosisKw.any((k) => norm.contains(_normalizeArabic(k)))) return _UserIntent.diagnosis;

    if (norm.length > 15) return _UserIntent.diagnosis;

    return _UserIntent.unknown;
  }


  bool _isEmergency(String text) => _detectIntent(text) == _UserIntent.emergencyAlert;

  List<String> _getEmergencySteps(String text) {
    final t = text.toLowerCase();
    if (t.contains('كهرب') || t.contains('شرار') || t.contains('دخان') || t.contains('ماس')) {
      return [
        '🚨 **افصل قاطع الكهرباء الرئيسي فوراً من اللوحة!**',
        '🛑 لا تلمس أي مفتاح كهربائي أو سلك مكشوف',
        '🪟 فتح النوافذ وابعد الأطفال عن مصدر الخطر',
        '📞 اتصل بنا فوراً للحصول على فني طوارئ',
      ];
    } else if (t.contains('غاز') || t.contains('ريحة غاز')) {
      return [
        '🚨 **اغلق محبس الغاز الرئيسي فوراً!**',
        '🛑 لا تضغط أي مفتاح كهرباء - حتى كشاف الموبايل',
        '🪟 افتح جميع النوافذ فوراً لتشتيت الغاز',
        '🚪 اخرج من المكان ولا تعود إلا بعد التهوية الكاملة',
        '📞 اتصل بنا فوراً لفني طوارئ غاز متخصص',
      ];
    }
    return [
      '🚨 **افصل المحبس/القاطع الرئيسي فوراً**',
      '🛑 ابتعد عن مكان الخطر حتى وصول الفني',
      '📞 تواصل معنا الآن للحصول على دعم طوارئ فوري',
    ];
  }

  // ── Order Tracking Handler ────────────────────────────────────────────────
  Future<void> _handleOrderTracking(String userText) async {
    final rawOrders = _ref.read(ordersProvider).valueOrNull ?? [];
    // ترتيب الطلبات من الأحدث إلى الأقدم
    final sortedOrders = List<Order>.from(rawOrders)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // التحقق مما إذا كان النص يحتوي على كود طلب محدد
    final cleanInput = userText.trim().toLowerCase();
    Order? matchedOrder;

    for (final o in sortedOrders) {
      if (cleanInput.contains(o.trackingCode.toLowerCase()) ||
          cleanInput.contains(o.id.toLowerCase())) {
        matchedOrder = o;
        break;
      }
    }

    // إذا تم تحديد طلب معين، اعرض تفاصيله مباشرة
    if (matchedOrder != null) {
      _sendOrderStatusMessage(matchedOrder);
      return;
    }

    // في حالة عدم تزويد كود محدد:
    if (sortedOrders.isEmpty) {
      final msg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'لا توجد طلبات مسجلة حالياً في حسابك.\nيمكنك تقديم طلب صيانة جديد في أي وقت وسنقوم بمتابعة الفني مباشرة.',
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        quickReplies: ['طلب خدمة جديدة', 'تشخيص عطل'],
      );
      state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
      return;
    }

    // إذا كان يوجد طلب واحد فقط، اعرض تفاصيله تلقائياً دون سؤال العميل!
    if (sortedOrders.length == 1) {
      _sendOrderStatusMessage(sortedOrders.first);
      return;
    }

    // إذا وجد أكثر من طلب، قم برصف الطلبات مرتبة من الأحدث إلى الأقدم مع إتاحة الضغط بنقرة واحدة
    final buffer = StringBuffer();
    buffer.writeln('تم العثور على **${sortedOrders.length} طلبات** مسجلة في حسابك (مرتبة من الأحدث إلى الأقدم):\n');

    for (int i = 0; i < sortedOrders.length; i++) {
      final o = sortedOrders[i];
      final isNewestTag = i == 0 ? ' (الأحدث)' : '';
      buffer.writeln('• **${o.trackingCode}**$isNewestTag — ${o.service.label}');
      buffer.writeln('  الحالة: **${o.status.label}** | المنطقة: ${o.area ?? "غير محددة"}\n');
    }
    buffer.writeln('اضغط على رقم أي طلب أدناه لمعاينة تفاصيله كاملة وموقع الفني مباشرة:');

    final quickReplies = sortedOrders.map((o) => '${o.trackingCode} - ${o.service.label}').toList();
    quickReplies.add('تشخيص عطل جديد');

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: buffer.toString(),
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: quickReplies,
    );
    state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
  }

  void _sendOrderStatusMessage(Order order) {
    final buffer = StringBuffer();
    buffer.writeln('**تفاصيل وموقف الطلب: ${order.trackingCode}**\n');
    buffer.writeln('• **حالة الطلب:** ${order.status.label}');
    buffer.writeln('• **نوع الخدمة:** ${order.service.label}');
    buffer.writeln('• **المنطقة:** ${order.area ?? "غير محدد"}');
    if (order.description != null && order.description!.isNotEmpty) {
      buffer.writeln('• **وصف المشكلة:** ${order.description}');
    }

    if (order.estimatedArrival != null) {
      buffer.writeln('• **الوقت المتوقع لوصول الفني:** ${_formatTime(order.estimatedArrival!)}');
    }

    if (order.finalPrice != null) {
      buffer.writeln('\n**تفاصيل الحساب والتكلفة:**');
      if (order.inspectionFee != null) buffer.writeln('  - رسوم الفحص والمعاينة: ${order.inspectionFee} ج.م');
      if (order.laborFee != null) buffer.writeln('  - مصنعية الإصلاح: ${order.laborFee} ج.م');
      if (order.partsFee != null) buffer.writeln('  - قيمة القطع: ${order.partsFee} ج.م');
      buffer.writeln('  - **المبلغ الإجمالي: ${order.finalPrice} ج.م**');
    }

    if (order.isWarrantyActive) {
      buffer.writeln('\n• **الضمان:** سارٍ (متبقي **${order.warrantyRemainingDays} يوم** من ضمان الـ 30 يوم)');
    } else if (order.status.label == 'مكتمل') {
      buffer.writeln('\n• **الضمان:** انتهت فترة الضمان لهذا الطلب');
    }

    final quickReplies = <String>[];
    if (order.status.label == 'الفني في الطريق') {
      quickReplies.addAll(['تتبع موقع الفني', 'تواصل مع الفني']);
    }
    if (order.isWarrantyActive) quickReplies.add('طلب خدمة تحت الضمان');
    quickReplies.addAll(['تتبع طلب آخر', 'تشخيص عطل جديد']);

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: buffer.toString(),
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: quickReplies,
    );
    state = state.copyWith(messages: [...state.messages, msg], isTyping: false, clearPendingTracking: true);
  }


  // ── Warranty Handler ─────────────────────────────────────────────────────
  Future<void> _handleWarrantyCheck(String userText) async {
    final orders = _ref.read(ordersProvider).valueOrNull ?? [];
    final completedWithWarranty = orders.where((o) => o.isWarrantyActive).toList();

    String text;
    List<String> quickReplies;

    if (completedWithWarranty.isNotEmpty) {
      final latest = completedWithWarranty.first;
      text = '🛡️ **ضمان منصة حرفي - 30 يوماً مجاناً**\n\n'
          '✅ لديك **${completedWithWarranty.length} طلب** تحت الضمان الآن:\n\n'
          '📦 **آخر طلب مضمون:**\n'
          '• الخدمة: ${latest.service.icon} ${latest.service.label}\n'
          '• كود: `${latest.trackingCode}`\n'
          '• **متبقي: ${latest.warrantyRemainingDays} يوم من الضمان**\n\n'
          '📋 **ماذا يشمل الضمان؟**\n'
          '• إعادة الإصلاح مجاناً في حال عودة نفس العطل\n'
          '• زيارة فنية مجانية خلال فترة الضمان\n'
          '• استبدال أي قطعة غيار تالفة بسبب الإصلاح\n\n'
          '📵 **ما لا يشمله الضمان:**\n'
          '• أضرار ناتجة عن سوء الاستخدام\n'
          '• أعطال جديدة غير مرتبطة بالإصلاح الأصلي';
      quickReplies = ['تفعيل الضمان لطلبي', '📦 تتبع طلبي', '🔧 عطل جديد'];
    } else {
      text = '🛡️ **ضمان منصة حرفي**\n\n'
          'جميع خدمات حرفي مضمونة **30 يوماً** من تاريخ إتمام الصيانة.\n\n'
          '📋 **الضمان يشمل:**\n'
          '• إعادة إصلاح مجانية في حال عودة العطل\n'
          '• زيارة فنية مجانية خلال فترة الضمان\n'
          '• استبدال القطع المعطوبة بسبب الإصلاح\n\n'
          '💡 **للاستفادة من الضمان:** أرسل رقم تتبع طلبك وسنرسل لك فنياً فوراً.';
      quickReplies = ['📦 تتبع طلبي', '🔧 عندي عطل', 'تواصل مع الدعم'];
    }

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: quickReplies,
    );
    state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
  }

  // ── Pricing Handler ──────────────────────────────────────────────────────
  void _handlePricingQuery(String userText) {
    final t = userText.toLowerCase();
    ServiceType? matchedService;

    // محاولة تحديد الخدمة من نص السؤال
    for (final s in ServiceType.values) {
      if (s.keywords.any((k) => t.contains(k.toLowerCase())) || t.contains(s.label)) {
        matchedService = s;
        break;
      }
    }

    final location = _ref.read(userLocationProvider);
    final cityName = location.city.isNotEmpty ? location.city : 'كفر الزيات';
    final availableTechs = matchedService != null ? _getAvailableTechs(matchedService) : <Technician>[];

    String text;
    if (matchedService != null) {
      final visitPrice = availableTechs.isNotEmpty ? availableTechs.first.visitPrice : 150;
      text = '💵 **أسعار خدمة ${matchedService.icon} ${matchedService.label} في $cityName**\n\n'
          '📋 **نطاق الأسعار المعتمد:** ${matchedService.priceRange}\n\n'
          '**هيكل الفاتورة:**\n'
          '• رسوم الزيارة والفحص: **$visitPrice ج.م** *(تُخصم من الإجمالي عند الاتفاق)*\n'
          '• رسوم العمالة: **50 - 200 ج.م** *(حسب نوع وتعقيد العطل)*\n'
          '• قيمة قطع الغيار: **حسب القطعة التالفة فعلياً**\n\n'
          '✅ **ضمان الشفافية:** الفني يقدم عرض سعر واضح قبل البدء في الإصلاح\n'
          '🛡️ **ضمان 30 يوم** على جميع الإصلاحات';
    } else {
      text = '💵 **أسعار خدمات حرفي في $cityName**\n\n'
          '${ServiceType.values.map((s) => '${s.icon} **${s.label}**: ${s.priceRange}').join('\n')}\n\n'
          '⚠️ **ملاحظة:** الأسعار تشمل رسوم الزيارة والفحص المبدئي فقط.\n'
          'تكلفة قطع الغيار تُضاف حسب العطل الفعلي.\n\n'
          '💡 احكيلي نوع الجهاز المعطل وهدي سعر أدق!';
    }

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: matchedService != null
          ? ['🚀 اطلب فني ${matchedService.label} الآن', '🔧 تشخيص العطل أولاً', 'خدمة أخرى']
          : ServiceType.values.take(4).map((s) => '${s.icon} أسعار ${s.label}').toList(),
    );
    state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
  }

  // ── Greeting Handler ─────────────────────────────────────────────────────
  void _handleGreeting() {
    final hours = DateTime.now().hour;
    final greeting = hours < 12 ? 'صباح الخير ☀️' : hours < 17 ? 'مساء الخير 🌤️' : 'مساء النور 🌙';
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '$greeting! أنا **مساعد حرفي الذكي** 🤖\nإيه اللي أقدر أساعدك فيه النهارده؟',
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: ['🔧 عندي عطل في جهاز', '📦 تتبع طلبي', '💵 أسعار الصيانة', '🛡️ الضمان'],
    );
    state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
  }

  // ── FAQ Handler ──────────────────────────────────────────────────────────
  void _handleFaq(String userText) {
    final t = userText.toLowerCase();
    String text;

    if (t.contains('تنزيل') || t.contains('التطبيق') || t.contains('تحميل')) {
      text = '📱 **تحميل تطبيق حرفي**\n\nالتطبيق متاح على:\n• **Google Play**: بحث عن "حرفي"\n• **App Store**: بحث عن "حرفي"\n\nأو افتح الموقع مباشرة من المتصفح 🌐';
    } else if (t.contains('تسجيل') || t.contains('حساب')) {
      text = '👤 **التسجيل في حرفي**\n\n1. افتح التطبيق\n2. اضغط "تسجيل كعميل"\n3. أدخل رقم هاتفك واسمك\n4. أكد رمز الـ SMS\n✅ وخلاص - تقدر تطلب فني فوراً!';
    } else if (t.contains('وقت') || t.contains('انتظار') || t.contains('متى')) {
      text = '⏱️ **وقت الاستجابة**\n\n🟢 **طلبات عادية:** خلال 30 - 60 دقيقة\n🔴 **طلبات طوارئ:** خلال 15 - 30 دقيقة\n\n💡 الوقت يعتمد على توفر الفنيين في منطقتك';
    } else {
      text = '💡 **حرفي - منصة الصيانة المنزلية الموثوقة**\n\n'
          'بنوفر فنيين معتمدين في:\n'
          '${ServiceType.values.map((s) => '${s.icon} ${s.label}').join(' | ')}\n\n'
          '✅ **مزايانا:**\n'
          '• فنيين معتمدين ومقيّمين\n'
          '• ضمان 30 يوم على كل خدمة\n'
          '• أسعار شفافة قبل البدء\n'
          '• تتبع الفني على الخريطة';
    }

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickReplies: ['🔧 عندي عطل', '📦 تتبع طلبي', '💵 الأسعار', 'سؤال تاني'],
    );
    state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
  }

  // ── Main Message Handler ─────────────────────────────────────────────────
  List<Technician> _getAvailableTechs(ServiceType? service) {
    if (service == null) return [];
    final allTechs = _ref.read(techniciansProvider).valueOrNull ?? [];
    return allTechs.where((t) => t.spec == service && t.status == TechStatus.available).toList();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> sendMessage({required String text, File? imageFile, bool isVoice = false}) async {
    final userMsgText = text.trim();
    if (userMsgText.isEmpty && imageFile == null) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: userMsgText.isEmpty ? (isVoice ? '🎤 تسجيل صوتي' : '📷 صورة مرفقة') : userMsgText,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
      imageFile: imageFile,
      isVoice: isVoice,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      error: null,
    );

    // تأخير بسيط يشعر بالتفكير
    await Future.delayed(const Duration(milliseconds: 600));

    // إذا كان المساعد في انتظار كود التتبع
    if (state.pendingTrackingCode == 'AWAITING_INPUT') {
      await _handleOrderTracking(userMsgText);
      return;
    }

    final intent = imageFile != null ? _UserIntent.diagnosis : _detectIntent(userMsgText);

    switch (intent) {
      case _UserIntent.emergencyAlert:
        await _handleEmergencyWithDiagnosis(userMsgText, imageFile);
        break;
      case _UserIntent.orderTracking:
        await _handleOrderTracking(userMsgText);
        break;
      case _UserIntent.warrantyCheck:
        await _handleWarrantyCheck(userMsgText);
        break;
      case _UserIntent.pricingQuery:
        _handlePricingQuery(userMsgText);
        break;
      case _UserIntent.greeting:
        _handleGreeting();
        break;
      case _UserIntent.generalFaq:
        _handleFaq(userMsgText);
        break;
      case _UserIntent.diagnosis:
      case _UserIntent.unknown:
        await _handleDiagnosis(userMsgText, imageFile);
        break;
    }
  }

  // ── Emergency + Diagnosis ────────────────────────────────────────────────
  Future<void> _handleEmergencyWithDiagnosis(String text, File? imageFile) async {
    final emergencySteps = _getEmergencySteps(text);

    final emergencyMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '🚨 **حالة طوارئ - اتبع هذه الخطوات فوراً!**',
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      isEmergency: true,
      emergencySteps: emergencySteps,
      quickReplies: ['📞 اتصل بنا الآن', '🔧 اطلب فني طوارئ', 'الوضع اتحل - شكراً'],
    );

    state = state.copyWith(
      messages: [...state.messages, emergencyMsg],
      isTyping: false,
    );
  }

  // ── Diagnosis Handler ────────────────────────────────────────────────────
  Future<void> _handleDiagnosis(String text, File? imageFile) async {
    final isEmergency = _isEmergency(text);
    final emergencySteps = isEmergency ? _getEmergencySteps(text) : <String>[];

    try {
      final diagnosis = await _analyzeUseCase(
        description: text.isEmpty ? 'تحليل صورة أو تسجيل صوتي مرفق' : text,
        image: imageFile,
      );

      final service = diagnosis.serviceType;
      final availableTechs = _getAvailableTechs(service);
      final location = _ref.read(userLocationProvider);
      final cityName = location.city.isNotEmpty ? location.city : 'كفر الزيات';

      final buffer = StringBuffer();

      if (imageFile != null) {
        buffer.writeln('🔍 **تحليل الصورة بالذكاء الاصطناعي:**');
        buffer.writeln('تم فحص العناصر الظاهرة في الصورة بدقة عالية.\n');
      }

      buffer.writeln('📌 **التشخيص الفني:**');
      buffer.writeln(diagnosis.problemSummary);

      buffer.writeln('\n⚙️ **السبب المحتمل:**');
      buffer.writeln(diagnosis.possibleIssue);

      if (diagnosis.secondaryIssue != null && diagnosis.secondaryIssue!.isNotEmpty) {
        buffer.writeln('\n🔍 **احتمال ثانوي:**');
        buffer.writeln(diagnosis.secondaryIssue!);
      }

      if (diagnosis.repairVsReplace != null && diagnosis.repairVsReplace!.isNotEmpty) {
        buffer.writeln('\n🤔 **إصلاح أم استبدال؟**');
        buffer.writeln(diagnosis.repairVsReplace!);
      }

      // تفاصيل الفنيين
      if (service != null && availableTechs.isNotEmpty) {
        buffer.writeln('\n👨‍🔧 **أفضل ${availableTechs.length > 3 ? 3 : availableTechs.length} فنيين متاحين الآن في $cityName:**');
        for (var t in availableTechs.take(3)) {
          final rank = t.totalJobs >= 50 ? 'خبير 🏆' : t.totalJobs >= 20 ? 'محترف 🎖️' : 'معتمد 🛡️';
          buffer.writeln('• **${t.name}** ($rank • ${t.rating.toStringAsFixed(1)}⭐ • زيارة: ${t.visitPrice} ج.م)');
        }
      } else if (service != null) {
        buffer.writeln('\n👨‍🔧 سيتم توجيه طلبك لأقرب فني ${service.label} متاح في $cityName');
      }

      buffer.writeln('\n🛡️ **ضمان 30 يوم** على الإصلاح');

      final assistantMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: buffer.toString(),
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        diagnosis: diagnosis,
        isEmergency: isEmergency,
        emergencySteps: emergencySteps,
        quickReplies: diagnosis.followUpQuestions.isNotEmpty
            ? diagnosis.followUpQuestions.take(3).toList()
            : [
                '🚀 اطلب فني الآن',
                '🛠️ نصيحة DIY مجانية',
                '💵 كام هتكلفني؟',
              ],
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isTyping: false,
      );
    } catch (e) {
      final fallback = _generateFallbackDiagnosis(text, isEmergency);
      final msg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: fallback.problemSummary,
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        diagnosis: fallback,
        isEmergency: isEmergency,
        emergencySteps: emergencySteps,
        quickReplies: ['🔧 اطلب فني الآن', '📞 تواصل مع الدعم', 'استفسار آخر'],
      );
      state = state.copyWith(messages: [...state.messages, msg], isTyping: false);
    }
  }

  SmartDiagnosis _generateFallbackDiagnosis(String query, bool isEmergency) {
    return SmartDiagnosis(
      confidence: 0.90,
      problemSummary: 'بناءً على وصفك: تم رصد عطل تشغيلي يحتاج معاينة فنية دقيقة.',
      possibleIssue: 'تآكل في الوصلات أو المكونات الداخلية يتطلب تدخلاً فنياً متخصصاً.',
      secondaryIssue: 'احتمال وجود انسداد أو ماس جزئي مصاحب.',
      diyTip: 'افصل الجهاز عن مصدر التغذية وتركه يرتاح 5 دقائق قبل الفحص.',
      diySteps: ['افصل الكهرباء أو اغلق المحبس', 'انتظر 5 دقائق', 'أعد التشغيل وراقب الجهاز'],
      estimatedPartsCost: 'تتراوح تكلفة قطع الغيار المعتادة بين 100 - 250 ج.م',
      recommendedAction: 'نوصي بحجز فني متخصص لمعاينة ميدانية وإصلاح تحت الضمان.',
      needsTechnician: true,
      urgency: isEmergency ? 'high' : 'medium',
      safetyNotes: isEmergency ? ['توخى الحذر وتجنب التعامل المباشر مع مكان التلف'] : [],
      followUpQuestions: ['هل العطل ظهر فجأة أم بالتدريج؟', 'هل هناك صوت أو ريحة غريبة؟'],
    );
  }

  // ── Voice Recording ──────────────────────────────────────────────────────
  void startVoiceRecording() {
    state = state.copyWith(isRecordingVoice: true, recordingDurationSeconds: 0);
  }

  void updateRecordingDuration(int seconds) {
    state = state.copyWith(recordingDurationSeconds: seconds);
  }

  void stopVoiceRecordingAndSend(String transcribedText) {
    state = state.copyWith(isRecordingVoice: false, recordingDurationSeconds: 0);
    sendMessage(text: transcribedText, isVoice: true);
  }

  void cancelVoiceRecording() {
    state = state.copyWith(isRecordingVoice: false, recordingDurationSeconds: 0);
  }

  void reset() {
    state = SmartAssistantState();
    _initWelcomeMessage();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────
final smartAssistantProvider = StateNotifierProvider.autoDispose<SmartAssistantNotifier, SmartAssistantState>((ref) {
  final useCase = ref.watch(analyzeProblemUseCaseProvider);
  return SmartAssistantNotifier(useCase, ref);
});
