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
  final List<String> diySteps;
  final String? estimatedPartsCost;
  final List<Map<String, String>> partsBreakdown;
  final String? repairVsReplace;
  final String intentType; // 'diagnosis', 'order_tracking', 'pricing', 'warranty', 'emergency', 'general_faq'
  final String? activeOrderSummary;
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
    this.diySteps = const [],
    this.estimatedPartsCost,
    this.partsBreakdown = const [],
    this.repairVsReplace,
    this.intentType = 'diagnosis',
    this.activeOrderSummary,
    this.analysisSource = 'expert_ai_3.0',
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
      if (cat == 'electricity' || cat == 'electrical') return name == 'electrical';
      if (cat == 'air_conditioning' || cat == 'ac') return name == 'ac';
      if (cat == 'washing_machine' || cat == 'washingmachines') return name == 'washingmachines';
      if (cat == 'refrigerator' || cat == 'refrigerators') return name == 'refrigerators';
      if (cat == 'stove' || cat == 'stoves') return name == 'stoves';
      if (cat == 'tv' || cat == 'screens') return name == 'screens';
      if (cat == 'plumbing') return name == 'plumbing';
      if (cat == 'carpentry') return name == 'carpentry';
      if (cat == 'water_heater') return name == 'heaters';
      return name == cat;
    }).firstOrNull;
  }
}

class FollowUpAnswer {
  final String question;
  final String answer;
  FollowUpAnswer(this.question, this.answer);
}
