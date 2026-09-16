import 'dart:io';
import 'smart_diagnosis.dart';

enum ChatSender { user, assistant }

class ChatMessage {
  final String id;
  final String text;
  final ChatSender sender;
  final DateTime timestamp;
  final File? imageFile;
  final String? imageUrl;
  final bool isVoice;
  final SmartDiagnosis? diagnosis;
  final bool isEmergency;
  final List<String> emergencySteps;
  final List<String> quickReplies;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.imageFile,
    this.imageUrl,
    this.isVoice = false,
    this.diagnosis,
    this.isEmergency = false,
    this.emergencySteps = const [],
    this.quickReplies = const [],
  });

  bool get isUser => sender == ChatSender.user;
}
