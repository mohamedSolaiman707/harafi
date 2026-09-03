import '../../../admin/domain/enums/service_type.dart';

class SmartDiagnosis {
  final String? detectedCategory;
  final String? categoryNameAr;
  final double confidence;
  final String confidenceLevel;
  final String problemSummary;
  final String possibleIssue;
  final String? secondaryIssue;
  final String recommendedAction;
  final String? diyTip;
  final String? estimatedPartsCost;
  final String analysisSource;
  final bool needsTechnician;
  final String urgency;
  final String? safetyLevel;
  final List<String> safetyNotes;
  final List<String> followUpQuestions;

  SmartDiagnosis({
    this.detectedCategory,
    this.categoryNameAr,
    required this.confidence,
    this.confidenceLevel = 'medium',
    required this.problemSummary,
    required this.possibleIssue,
    this.secondaryIssue,
    this.recommendedAction = '',
    this.diyTip,
    this.estimatedPartsCost,
    this.analysisSource = 'openai',
    required this.needsTechnician,
    required this.urgency,
    this.safetyLevel,
    this.safetyNotes = const [],
    this.followUpQuestions = const [],
  });

  ServiceType? get serviceType {
    if (detectedCategory == null) return null;
    return ServiceType.values.where((e) {
      final name = e.name.toLowerCase();
      final cat = detectedCategory!.toLowerCase();
      if (cat == 'electricity') return name == 'electrical';
      if (cat == 'air_conditioning') return name == 'ac';
      if (cat == 'washing_machine') return name == 'washingmachines';
      if (cat == 'refrigerator') return name == 'refrigerators';
      if (cat == 'stove') return name == 'stoves';
      if (cat == 'tv') return name == 'screens';
      return name == cat;
    }).firstOrNull;
  }
}

class FollowUpAnswer {
  final String question;
  final String answer;
  FollowUpAnswer(this.question, this.answer);
}
