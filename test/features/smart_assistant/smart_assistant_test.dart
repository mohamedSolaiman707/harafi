import 'package:flutter_test/flutter_test.dart';
import 'package:harafi/features/smart_assistant/domain/entities/chat_message.dart';
import 'package:harafi/features/smart_assistant/domain/entities/smart_diagnosis.dart';
import 'package:harafi/features/admin/domain/enums/service_type.dart';

void main() {
  group('SmartAssistant Entities Unit Tests', () {
    test('ChatMessage properties and user flag test', () {
      final msg = ChatMessage(
        id: 'msg_1',
        text: 'عندي مشكلة في الغسالة',
        sender: ChatSender.user,
        timestamp: DateTime(2026, 10, 4, 10, 0),
      );

      expect(msg.id, 'msg_1');
      expect(msg.isUser, isTrue);
      expect(msg.sender, ChatSender.user);
    });

    test('ChatMessage assistant sender test', () {
      final msg = ChatMessage(
        id: 'msg_2',
        text: 'مرحباً بك في مساعد حرفي',
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        contactPhone: '19000',
        quickReplies: ['طلب فني طوارئ'],
      );

      expect(msg.isUser, isFalse);
      expect(msg.contactPhone, '19000');
      expect(msg.quickReplies, contains('طلب فني طوارئ'));
    });

    test('SmartDiagnosis category mapping test', () {
      final diagnosisWashing = SmartDiagnosis(
        detectedCategory: 'washing_machine',
        categoryNameAr: 'غسالات',
        confidence: 0.85,
        problemSummary: 'تلف طلمبة الطرد',
        possibleIssue: 'انسداد الفلتر أو تلف السير',
        needsTechnician: true,
        urgency: 'normal',
      );

      expect(diagnosisWashing.serviceType, ServiceType.washingMachines);

      final diagnosisAC = SmartDiagnosis(
        detectedCategory: 'air_conditioning',
        categoryNameAr: 'تكييفات',
        confidence: 0.9,
        problemSummary: 'تسريب فريون',
        possibleIssue: 'شحن فريون R22',
        needsTechnician: true,
        urgency: 'normal',
      );

      expect(diagnosisAC.serviceType, ServiceType.ac);
    });
  });
}
