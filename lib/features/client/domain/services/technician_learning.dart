import '../../../admin/domain/enums/tech_status.dart';

class TechnicianLearningMetrics {
  final String technicianId;
  final int totalOutcomes;
  final int firstVisitFixes;
  final int repeatIssues;
  final int warrantyClaims;
  final int ratedJobs;
  final double firstVisitFixRate;
  final double repeatIssueRate;
  final double warrantyClaimRate;
  final double averageRating;
  final double reliabilityScore;
  final double avgResolutionMinutes;

  const TechnicianLearningMetrics({
    required this.technicianId,
    required this.totalOutcomes,
    required this.firstVisitFixes,
    required this.repeatIssues,
    required this.warrantyClaims,
    required this.ratedJobs,
    required this.firstVisitFixRate,
    required this.repeatIssueRate,
    required this.warrantyClaimRate,
    required this.averageRating,
    required this.reliabilityScore,
    required this.avgResolutionMinutes,
  });
}

TechnicianLearningMetrics buildTechnicianLearningMetrics(
  String technicianId,
  Map<String, dynamic> technician,
  List<Map<String, dynamic>> outcomes,
) {
  final techOutcomes = outcomes
      .where((row) => row['recommended_technician_id']?.toString() == technicianId)
      .toList();
  final totalOutcomes = techOutcomes.length;
  final firstVisitFixes = techOutcomes.where((row) => row['first_visit_fix'] == true).length;
  final repeatIssues = techOutcomes.where((row) => row['repeat_issue'] == true).length;
  final warrantyClaims = techOutcomes.where((row) => row['warranty_claimed'] == true).length;
  final ratedJobs = techOutcomes.where((row) => row['customer_rating'] != null).length;
  final totalRating = techOutcomes.fold<double>(
    0,
    (sum, row) => sum + ((row['customer_rating'] as num?)?.toDouble() ?? 0),
  );
  final totalResolutionMinutes = techOutcomes.fold<double>(
    0,
    (sum, row) => sum + ((row['resolution_time_minutes'] as num?)?.toDouble() ?? 0),
  );

  final firstVisitFixRate = totalOutcomes == 0 ? 0.0 : firstVisitFixes / totalOutcomes;
  final repeatIssueRate = totalOutcomes == 0 ? 0.0 : repeatIssues / totalOutcomes;
  final warrantyClaimRate = totalOutcomes == 0 ? 0.0 : warrantyClaims / totalOutcomes;
  final ratingFromHistory = ratedJobs == 0
      ? (technician['rating'] as num?)?.toDouble() ?? 0.0
      : totalRating / ratedJobs;
  final reliabilityScore = calculateReliabilityScore(
    totalOutcomes: totalOutcomes,
    firstVisitFixRate: firstVisitFixRate,
    repeatIssueRate: repeatIssueRate,
    warrantyClaimRate: warrantyClaimRate,
    averageRating: ratingFromHistory,
    isVerified: technician['is_verified'] == true,
    status: technician['status']?.toString() ?? '',
  );

  return TechnicianLearningMetrics(
    technicianId: technicianId,
    totalOutcomes: totalOutcomes,
    firstVisitFixes: firstVisitFixes,
    repeatIssues: repeatIssues,
    warrantyClaims: warrantyClaims,
    ratedJobs: ratedJobs,
    firstVisitFixRate: firstVisitFixRate,
    repeatIssueRate: repeatIssueRate,
    warrantyClaimRate: warrantyClaimRate,
    averageRating: ratingFromHistory,
    reliabilityScore: reliabilityScore,
    avgResolutionMinutes:
        totalOutcomes == 0 ? 0.0 : totalResolutionMinutes / totalOutcomes,
  );
}

bool isEligibleForAutoPick(TechnicianLearningMetrics metrics, {double threshold = 60}) {
  return metrics.reliabilityScore >= threshold;
}

String buildLearningSummary(TechnicianLearningMetrics metrics) {
  final parts = <String>[];
  if (metrics.totalOutcomes >= 5 && metrics.firstVisitFixRate >= 0.7) {
    parts.add('حل من أول زيارة');
  }
  if (metrics.totalOutcomes >= 5 && metrics.repeatIssueRate <= 0.1) {
    parts.add('رجوع أعطال منخفض');
  }
  if (metrics.warrantyClaimRate <= 0.1 && metrics.totalOutcomes >= 3) {
    parts.add('شكاوى ضمان قليلة');
  }
  if (metrics.reliabilityScore >= 80) {
    parts.add('موثوق جدًا');
  }
  if (parts.isEmpty) {
    parts.add('تعلّم من الطلبات الفعلية');
  }
  return parts.take(3).join(' · ');
}

double calculateReliabilityScore({
  required int totalOutcomes,
  required double firstVisitFixRate,
  required double repeatIssueRate,
  required double warrantyClaimRate,
  required double averageRating,
  required bool isVerified,
  required String status,
}) {
  final jobsComponent = totalOutcomes >= 40
      ? 25
      : totalOutcomes >= 20
          ? 18
          : totalOutcomes >= 10
              ? 10
              : totalOutcomes >= 3
                  ? 5
                  : 0;
  final fixComponent = (firstVisitFixRate * 45).clamp(0, 45);
  final repeatPenalty = (repeatIssueRate * 28).clamp(0, 28);
  final warrantyPenalty = (warrantyClaimRate * 12).clamp(0, 12);
  final ratingComponent = ((averageRating / 5.0) * 20).clamp(0, 20);
  final verificationComponent = isVerified ? 5 : 0;
  final statusComponent = status.contains('متاح')
      ? 5
      : status.contains('مشغول')
          ? 2
          : 0;

  final raw = jobsComponent +
      fixComponent +
      ratingComponent +
      verificationComponent +
      statusComponent -
      repeatPenalty -
      warrantyPenalty;
  return raw.clamp(0, 100).toDouble();
}
