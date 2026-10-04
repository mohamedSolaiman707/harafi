import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/smart_diagnosis.dart';
import '../../domain/repositories/smart_assistant_repository.dart';
import '../models/smart_diagnosis_model.dart';

class SupabaseSmartAssistantRepository implements SmartAssistantRepository {
  final SupabaseClient _client;

  SupabaseSmartAssistantRepository(this._client);

  @override
  Future<String?> getOrCreateActiveSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final existingSessions = await _client
          .from('chat_sessions')
          .select('id')
          .eq('user_id', user.id)
          .order('last_message_at', ascending: false)
          .limit(1);

      if (existingSessions.isNotEmpty) {
        return existingSessions.first['id'] as String;
      }

      final newSession = await _client
          .from('chat_sessions')
          .insert({
            'user_id': user.id,
            'title': 'محادثة صيانة جارية',
          })
          .select('id')
          .single();

      return newSession['id'] as String;
    } catch (e) {
      debugPrint('Error getting or creating chat session: $e');
      return null;
    }
  }

  @override
  Future<List<ChatMessage>> loadSessionMessages(String sessionId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select('*')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return (response as List).map((map) {
        final role = map['role'] as String? ?? 'user';
        final isUser = role == 'user';
        final emergencyStepsList = (map['emergency_steps'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final quickRepliesList = (map['quick_replies'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        SmartDiagnosis? diagnosis;
        if (map['diagnosis'] != null && map['diagnosis'] is Map) {
          try {
            diagnosis = SmartDiagnosisModel.fromJson(
              Map<String, dynamic>.from(map['diagnosis'] as Map),
            );
          } catch (_) {}
        }

        return ChatMessage(
          id: map['id'].toString(),
          text: map['content'] as String? ?? '',
          sender: isUser ? ChatSender.user : ChatSender.assistant,
          timestamp: map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
          imageUrl: map['image_url'] as String?,
          isEmergency: (map['intent'] as String?) == 'emergency',
          emergencySteps: emergencyStepsList,
          quickReplies: quickRepliesList,
          contactPhone: map['contact_phone'] as String?,
          diagnosis: diagnosis,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading chat session messages: $e');
      return [];
    }
  }

  @override
  Future<AgentChatResponse> sendAgentMessage({
    String? sessionId,
    required String message,
    File? image,
    Map<String, dynamic>? context,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (sessionId != null) 'session_id': sessionId,
        'message': message,
        if (context != null) 'context': context,
      };

      if (image != null) {
        payload['image_base64'] = base64Encode(await image.readAsBytes());
      }

      final response = await _client.functions.invoke(
        'agent-chat',
        body: payload,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final returnedSessionId = data['session_id'] as String?;
        final returnedMsgId = data['message_id'] as int?;
        final reply = data['reply'] as String? ?? '';
        final intent = data['intent'] as String? ?? 'general_query';

        final emergencySteps = (data['emergency_steps'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final quickReplies = (data['quick_replies'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final contactPhone = data['contact_phone'] as String?;

        return AgentChatResponse(
          sessionId: returnedSessionId,
          messageId: returnedMsgId,
          reply: reply,
          intent: intent,
          emergencySteps: emergencySteps,
          quickReplies: quickReplies,
          contactPhone: contactPhone,
        );
      }
    } catch (e) {
      debugPrint('agent-chat Edge Function error: $e');
    }

    final legacyDiagnosis = await analyzeProblem(
      description: message,
      image: image,
    );

    return AgentChatResponse(
      sessionId: sessionId,
      reply: legacyDiagnosis.problemSummary,
      intent: legacyDiagnosis.needsTechnician ? 'diagnosis' : 'general_query',
      quickReplies: legacyDiagnosis.followUpQuestions,
      diagnosis: legacyDiagnosis,
    );
  }

  @override
  Future<void> submitMessageFeedback({
    required int messageId,
    required int rating,
  }) async {
    try {
      await _client
          .from('chat_messages')
          .update({'feedback': rating})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
    }
  }

  @override
  Future<SmartDiagnosis> analyzeProblem({
    required String description,
    File? image,
    List<FollowUpAnswer> answers = const [],
  }) async {
    try {
      final payload = <String, dynamic>{
        'description': description.trim(),
        'answers': answers
            .map((a) => {'question': a.question, 'answer': a.answer})
            .toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (image != null) {
        payload['image_base64'] = base64Encode(await image.readAsBytes());
        payload['image_name'] = image.path.split(Platform.pathSeparator).last;
      }

      final response = await _client.functions.invoke(
        'analyze-problem',
        body: payload,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        final diagnosis = SmartDiagnosisModel.fromJson(data);
        if (diagnosis.possibleIssue.isNotEmpty &&
            !diagnosis.possibleIssue.contains('نحتاج تفاصيل أكثر')) {
          return diagnosis;
        }
      }
    } catch (e) {
      debugPrint('AI Agent Edge Function call error: $e');
    }

    return _buildLocalOfflineDiagnosis(description);
  }

  SmartDiagnosis _buildLocalOfflineDiagnosis(String text) {
    final lower = text.toLowerCase();

    // 1. ثلاجات / ديب فريزر
    if (lower.contains('ثلاج') || lower.contains('تلاج') || lower.contains('فريزر')) {
      return SmartDiagnosis(
        detectedCategory: 'refrigerator',
        categoryNameAr: 'ثلاجات',
        confidence: 0.80,
        confidenceLevel: 'high',
        problemSummary: 'عطل في التبريد أو انسداد فتحات الديفروست أو تلف الكاوتش',
        possibleIssue: 'ضعف غاز الفريون، انسداد فتحات الهواء، أو تلف ثرموستات وسخان الفريزر.',
        diyTip: 'افصل الثلاجة لمدة 6 ساعات لتذويب الثلج المتراكم في المجرى الداخلي وافحص إحكام الكاوتش المطاطي.',
        estimatedPartsCost: 'من 200 إلى 450 ج.م (ثرموستات ديفروست أو شحن فريون)',
        recommendedAction: 'طلب فني تبريد لفحص شحنة الفريون والكمبروسر.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['تأكد من عدم ترك باب الثلاجة مفتوحاً لفترات طويلة.'],
        followUpQuestions: ['هل الفريزر يجمد بشكل طبيعي والكابينة فقط دافئة؟', 'هل تسمع صوت الكباش الخارجي؟'],
      );
    }

    // 2. غسالات
    if (lower.contains('غسال')) {
      return SmartDiagnosis(
        detectedCategory: 'washing_machine',
        categoryNameAr: 'غسالات',
        confidence: 0.80,
        confidenceLevel: 'high',
        problemSummary: 'عطل محتمل في طلمبة الطرد أو سير الموتور والغسيل',
        possibleIssue: 'انسداد مصفاة الفلتر السفلية أو تلف طلمبة طرد المياه أو تآكل سير الغسالة.',
        diyTip: 'قم بفتح غطاء الفلتر الأسفل وتنظيف الرواسب والعملات المعدنية المحشورة ثم أعد تشغيل برنامج العصر.',
        estimatedPartsCost: 'من 180 إلى 320 ج.م (طلمبة طرد أو سير أصلي)',
        recommendedAction: 'طلب فني صيانة غسالات لفحص الطلمبة والكارتة الإلكترونية.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['افصل القابس الكهربائي قبل تنظيف الفلتر أو فك أي جزء حماية.'],
        followUpQuestions: ['هل الغسالة أوتوماتيك أم فوق أوتوماتيك؟', 'هل تظهر أي رموز خطأ مثل E3 أو E4؟'],
      );
    }

    // 3. تكييفات
    if (lower.contains('تكييف') || lower.contains('مكيف')) {
      return SmartDiagnosis(
        detectedCategory: 'air_conditioning',
        categoryNameAr: 'تكييفات',
        confidence: 0.80,
        confidenceLevel: 'high',
        problemSummary: 'انخفاض كفاءة التبريد أو تسريب مية من الوحدة الداخلية',
        possibleIssue: 'انسداد فلاتر الهواء الداخلية، أو انسداد خرطوم الصرف، أو نقص شحنة فريون R22/R410a.',
        diyTip: 'قم بفك الفلاتر البلاستيكية واغسلها بالماء المعتدل وافحص خرطوم التكثيف الخارجي.',
        estimatedPartsCost: 'من 350 إلى 750 ج.م (شحن فريون أصلي أو مكثف كباش)',
        recommendedAction: 'طلب فني تكييفات لقياس الضغط وشحن الفريون وتنظيف الحوض.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['لا تلمس كباش التكييف الخارجي أثناء التشغيل.'],
        followUpQuestions: ['هل التكييف ينقط مية داخل الغرفة؟', 'هل الكباش الخارجي يعمل بصوت طبيعي؟'],
      );
    }

    // 4. بوتاجازات وفرن
    if (lower.contains('بوتاجاز') || lower.contains('فرن') || lower.contains('شعلة')) {
      return SmartDiagnosis(
        detectedCategory: 'stove',
        categoryNameAr: 'بوتاجازات',
        confidence: 0.80,
        confidenceLevel: 'high',
        problemSummary: 'انسداد فونيات النار أو انسداد الإشعال الذاتي والفرن',
        possibleIssue: 'تراكم دهون الطعام داخل الفونية، أو انسداد شمعة الإشعال الذاتي، أو تلف المنظم.',
        diyTip: 'استخدم إبرة رفيعة جداً لتسليك الفونية المسدودة بعد غسل غطاء الشعلة بالخل والماء الدافئ.',
        estimatedPartsCost: 'من 90 إلى 220 ج.م (طقم فونيات أو شمعة إشعال)',
        recommendedAction: 'طلب فني صيانة بوتاجازات للتأكد من سلامة وصلة الغاز والمنظم.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['أغلق محبس الغاز دائماً قبل البدء بتنظيف الشعلات.'],
        followUpQuestions: ['هل النار حمراء/تهبب أم ضعيفة صفراء؟', 'هل الإشعال الذاتي يخرج شرارة؟'],
      );
    }

    // 5. سباكة
    if (lower.contains('سباك') || lower.contains('تسريب') || lower.contains('تنقيط') || lower.contains('حنفية') || lower.contains('خلاط')) {
      return SmartDiagnosis(
        detectedCategory: 'plumbing',
        categoryNameAr: 'سباكة',
        confidence: 0.80,
        confidenceLevel: 'high',
        problemSummary: 'تسريب في خلاط المياه أو تلف جلدة القلب المحول أو انسداد الصرف',
        possibleIssue: 'تآكل جلبة القلب الداخلي للخلاط أو انسداد السيفون برواسب السباكة.',
        diyTip: 'افحص الفلتر الخارجي (المرشح) في رأس الخلاط وقم بفكه وتنظيف التكلسات الكلسية.',
        estimatedPartsCost: 'من 80 إلى 190 ج.م (قلب خلاط سيراميك أو طقم جلد)',
        recommendedAction: 'طلب سباك متخصص لمعاينة التسريب واختبار ضغط المواسير.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['أغلق محبس الشقة الرئيسي قبل تفكيك أجزاء الخلاط.'],
        followUpQuestions: ['هل التسريب من المحبس السفلية أم من قلب الخلاط؟', 'هل يوجد تنقيط مستمر؟'],
      );
    }

    // 6. كهرباء
    if (lower.contains('كهربا') || lower.contains('فيشة') || lower.contains('مفتاح') || lower.contains('قاطع')) {
      return SmartDiagnosis(
        detectedCategory: 'electricity',
        categoryNameAr: 'كهرباء',
        confidence: 0.80,
        confidenceLevel: 'high',
        problemSummary: 'تذبذب في التيار أو قفلة بمفتاح القاطع الرئيسي',
        possibleIssue: 'زيادة حمل على المفتاح الأوتوماتيكي أو رخاوة مسامير التوصيل داخل اللوحة.',
        diyTip: 'فصل الأجهزة ذات الاستهلاك العالي (مثل السخان والتكييف) وافحص القاطع الرئيسي.',
        estimatedPartsCost: 'من 120 إلى 280 ج.م (مفتاح قاطع شيلدر / شنايدر أصلي)',
        recommendedAction: 'طلب كهربائي معتمد لفحص اللوحة وترميز خطوط الأحمال.',
        needsTechnician: true,
        urgency: 'high',
        analysisSource: 'fallback',
        safetyNotes: ['افصل القاطع الرئيسي فوراً في حال وجود رائحة شياط أو شرار.'],
        followUpQuestions: ['هل المفتاح يفصل فوراً بمجرد رفعه؟', 'هل ينبعث صوت زنة من اللوحة؟'],
      );
    }

    // General default fallback
    return SmartDiagnosis(
      detectedCategory: 'general',
      categoryNameAr: 'خدمة فنية',
      confidence: 0.70,
      confidenceLevel: 'medium',
      problemSummary: 'تم استلام تفاصيل جهازك واستعداد الفنيين للمعاينة',
      possibleIssue: 'نحتاج لمعرفة الأعراض الملاحظة (مثل: عدم دوران، تسريب مية، صوت مرتفع، أو توقف كامل).',
      diyTip: 'تأكد من توصيل الكهرباء/الغاز وإحكام الأبواب والأغطية قبل طلب الفني.',
      diySteps: [
        'اكتب نوع الجهاز وموديله (مثل: ثلاجة توشيبا 14 قدم)',
        'صف الأعراض بدقة (صوت خبط، مش بتسقع، بتنقط)',
      ],
      estimatedPartsCost: 'يتم تقديرها بدقة بعد معاينة الفني المباشرة',
      recommendedAction: 'طلب فني متخصص لموقعك للمعاينة والإصلاح مع الضمان',
      needsTechnician: true,
      urgency: 'normal',
      analysisSource: 'fallback',
      safetyNotes: ['في حالة الطوارئ (كهرباء / غاز) قم بفصل القاطع أو المحبس فوراً.'],
      followUpQuestions: ['ما هي الماركة والموديل التقريبي للجهاز؟', 'متى بدأت تلاحظ المشكلة؟'],
    );
  }
}
