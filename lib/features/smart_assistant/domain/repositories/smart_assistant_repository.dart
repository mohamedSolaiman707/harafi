import 'dart:io';
import '../entities/chat_message.dart';
import '../entities/smart_diagnosis.dart';

class AgentChatResponse {
  final String? sessionId;
  final int? messageId;
  final String reply;
  final String intent;
  final List<String> emergencySteps;
  final List<String> quickReplies;
  final String? contactPhone;
  final SmartDiagnosis? diagnosis;

  AgentChatResponse({
    this.sessionId,
    this.messageId,
    required this.reply,
    required this.intent,
    this.emergencySteps = const [],
    this.quickReplies = const [],
    this.contactPhone,
    this.diagnosis,
  });
}

abstract class SmartAssistantRepository {
  Future<SmartDiagnosis> analyzeProblem({
    required String description,
    File? image,
    List<FollowUpAnswer> answers = const [],
  });

  Future<AgentChatResponse> sendAgentMessage({
    String? sessionId,
    required String message,
    File? image,
    Map<String, dynamic>? context,
  });

  Future<List<ChatMessage>> loadSessionMessages(String sessionId);

  Future<String?> getOrCreateActiveSession();

  Future<void> submitMessageFeedback({
    required int messageId,
    required int rating, // 1 for thumbs up, -1 for thumbs down
  });
}
