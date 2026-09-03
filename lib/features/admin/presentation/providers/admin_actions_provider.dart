import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/failures.dart';
import '../../domain/business/admin_business_rules.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/order.dart';
import '../../domain/models/technician.dart';
import '../../domain/models/wallet_recharge.dart';
import 'wallet_recharges_provider.dart';
import 'orders_provider.dart';
import 'techs_provider.dart';
import 'promo_codes_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/either.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/whatsapp_otp_service.dart';
import '../../data/repositories/job_outcomes_repository.dart';
final adminActionsProvider = Provider<AdminActions>((ref) {
  return AdminActions(ref);
});

class AdminActions {
  final Ref _ref;
  AdminActions(this._ref);

  /// إنشاء طلب جديد
  Future<Either<Failure, Order>> createOrder(Order order) async {
    try {
      final result = await _ref.read(ordersRepositoryProvider).create(order);

      if (order.techId != null && order.techId!.isNotEmpty) {
        await _ref.read(techsRepositoryProvider).updateTechStatus(order.techId!, TechStatus.busy);
        _ref.invalidate(techsStreamProvider);
      }

      // زيادة عداد استخدامات الكوبون تلقائياً عند التطبيق
      if (order.promoCode != null && order.promoCode!.trim().isNotEmpty) {
        try {
          final cleanCode = order.promoCode!.trim().toUpperCase();
          final promoData = await Supabase.instance.client
              .from('promo_codes')
              .select('id, current_uses')
              .eq('code', cleanCode)
              .maybeSingle();

          if (promoData != null) {
            final currentUses = (promoData['current_uses'] as num?)?.toInt() ?? 0;
            await Supabase.instance.client
                .from('promo_codes')
                .update({'current_uses': currentUses + 1})
                .eq('id', promoData['id']);

            _ref.invalidate(promoCodesStreamProvider);
          }
        } catch (e) {
          debugPrint('خطأ أثناء تحديث استخدامات الكوبون: $e');
        }
      }

      _ref.invalidate(ordersStreamProvider);
      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  /// إنهاء الطلب وتحديث إحصائيات الفني
  Future<Either<Failure, Order>> completeOrder(
    Order order, {
    int? finalPrice,
    int? inspectionFee,
    int? laborFee,
    int? partsFee,
    String? techNotes,
    String? logMessage,
    Map<String, dynamic>? outcomeData,
  }) async {
    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(
          order.id,
          OrderStatus.completed,
          finalPrice: finalPrice,
          inspectionFee: inspectionFee,
          laborFee: laborFee,
          partsFee: partsFee,
          techNotes: techNotes,
          completedAt: DateTime.now(),
          logMessage: logMessage,
        );

    return await statusResult.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        final techId = updatedOrder.techId ?? order.techId;

        if (techId != null) {
          try {
            final techResult = await _ref.read(techsRepositoryProvider).getTechnicianById(techId);
            await techResult.when(
              left: (f) async {
                debugPrint('فشل جلب الفني لتحديث إحصائياته: ${f.message}');
              },
              right: (tech) async {
                final fee = AppConstants.platformFee;
                final newWalletBalance = (tech.walletBalance - fee) >= 0 ? (tech.walletBalance - fee) : 0;
                await _ref.read(techsRepositoryProvider).update(techId, {
                  'status': TechStatus.available.label,
                  'total_jobs': tech.totalJobs + 1,
                  'total_earnings': tech.totalEarnings + (finalPrice ?? 0),
                  'wallet_balance': newWalletBalance,
                  'phone': tech.phone,
                });

                final outcomeResult = await _ref.read(jobOutcomesRepositoryProvider).create({
                  'order_id': updatedOrder.id,
                  'customer_id': updatedOrder.clientPhone,
                  'ai_detected_category': updatedOrder.service.name,
                  'ai_category_name_ar': updatedOrder.service.label,
                  'ai_problem_summary': updatedOrder.description ?? '',
                  'ai_possible_issue': updatedOrder.description ?? '',
                  'ai_recommended_action': techNotes ?? '',
                  'ai_analysis_source': 'openai',
                  'recommended_technician_id': techId,
                  'technician_actual_diagnosis': outcomeData?['technician_actual_diagnosis'] ?? techNotes ?? '',
                  'repair_action_taken': outcomeData?['repair_action_taken'] ?? techNotes ?? '',
                  'first_visit_fix': outcomeData?['first_visit_fix'] ?? true,
                  'repeat_issue': outcomeData?['repeat_issue'] ?? false,
                  'warranty_claimed': outcomeData?['warranty_claimed'] ?? false,
                  'customer_rating': updatedOrder.rating,
                  'customer_feedback': updatedOrder.ratingComment,
                  'final_cost': finalPrice,
                  'inspection_fee': inspectionFee ?? 0,
                  'labor_fee': laborFee ?? 0,
                  'parts_fee': partsFee ?? 0,
                  'parts_used': outcomeData?['parts_used'],
                  'resolution_time_minutes': updatedOrder.completedAt != null
                      ? DateTime.now().difference(updatedOrder.createdAt).inMinutes
                      : null,
                });

                outcomeResult.when(
                  left: (f) => debugPrint('فشل حفظ نتيجة الطلب: ${f.message}'),
                  right: (_) {},
                );

                _ref.invalidate(techsStreamProvider);
                _ref.invalidate(ordersStreamProvider);
              },
            );
          } catch (e) {
            debugPrint('خطأ أثناء تحديث إحصائيات الفني: $e');
          }
        }
        return Right(updatedOrder);
      },
    );
  }

  /// إلغاء الطلب وإرجاع الفني إن وجد
  Future<Either<Failure, Order>> cancelOrder(Order order, {String? logMessage}) async {
    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(order.id, OrderStatus.cancelled, logMessage: logMessage);

    return await statusResult.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        if (order.techId != null) {
          await _ref.read(techsRepositoryProvider).updateTechStatus(order.techId!, TechStatus.available);
          _ref.invalidate(techsStreamProvider);
        }
        _ref.invalidate(ordersStreamProvider);
        return Right(updatedOrder);
      },
    );
  }

  /// رفض/اعتذار الفني عن الطلب مع إبلاغ العميل بواتساب
  /// ????? ??? ????
  Future<Either<Failure, Order>> assignTech(Order order, Technician tech) async {
    if (!AdminBusinessRules.canAssignTech(tech, order)) {
      return Left(BusinessException('????? ??? ???? ??????'));
    }

    final assignment = await _ref.read(ordersRepositoryProvider).assignTechnician(order.id, tech.id);

    return await assignment.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        await _ref.read(techsRepositoryProvider).updateTechStatus(tech.id, TechStatus.busy);
        WhatsAppOtpService.sendTechAssignmentNotification(tech: tech, order: updatedOrder);
        _ref.invalidate(techsStreamProvider);
        _ref.invalidate(ordersStreamProvider);
        return Right(updatedOrder);
      },
    );
  }
  Future<Either<Failure, Order>> rejectOrderByTech(
    Order order, {
    String? reason,
  }) async {
    final String cleanReason = reason?.trim() ?? '';
    final String logMessage = cleanReason.isNotEmpty
        ? '????? ????? ?? ??????? ?????. ?????: $cleanReason'
        : '????? ????? ?? ??????? ?????';

    final assignmentLog = order.logs
        .where((log) => log.status == OrderStatus.assigned)
        .map((log) => log.timestamp)
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) return current;
          return latest;
        });
    final isLateResponse = assignmentLog != null &&
        DateTime.now().isAfter(assignmentLog.add(const Duration(minutes: 3)));

    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(
          order.id,
          OrderStatus.cancelled,
          techNotes: cleanReason.isNotEmpty
              ? '??? ?????? ?????: $cleanReason'
              : '????? ????? ?? ??????? ?????',
          logMessage: isLateResponse ? '$logMessage ??? ?????? ???? ????' : logMessage,
        );

    return await statusResult.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        if (order.techId != null && order.techId!.isNotEmpty) {
          await _ref
              .read(techsRepositoryProvider)
              .updateTechStatus(order.techId!, TechStatus.available);
          _ref.invalidate(techsStreamProvider);
          _ref.invalidate(techniciansProvider);
          _ref.invalidate(currentTechnicianProvider);
        }

        WhatsAppOtpService.sendOrderRejectionNotificationToClient(
          order: updatedOrder,
          reason: cleanReason.isNotEmpty ? cleanReason : null,
        );

        _ref.invalidate(ordersStreamProvider);
        return Right(updatedOrder);
      },
    );
  }
  Future<Either<Failure, Order>> updateOrderStatus(
    Order order,
    OrderStatus status, {
    int? finalPrice,
    String? techNotes,
    String? logMessage,
  }) async {
    if (!AdminBusinessRules.canMoveOrderTo(order.status, status)) {
      return Left(BusinessException('لا يمكن نقل الطلب إلى هذه الحالة من وضعه الحالي'));
    }
    if (status == OrderStatus.completed) {
      return await completeOrder(order, finalPrice: finalPrice, techNotes: techNotes, logMessage: logMessage);
    }
    if (status == OrderStatus.cancelled) {
      return await cancelOrder(order, logMessage: logMessage);
    }
    final result = await _ref.read(ordersRepositoryProvider).updateOrderStatus(order.id, status, logMessage: logMessage);
    _ref.invalidate(ordersStreamProvider);
    return result;
  }

  /// تقييم الطلب وتحديث متوسط تقييم الفني
  Future<Either<Failure, Order>> rateOrder(String orderId, int rating, {String? comment}) async {
    final result = await _ref.read(ordersRepositoryProvider).rateOrder(orderId, rating, comment: comment);

    return await result.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        final techId = updatedOrder.techId;
        if (techId != null) {
          try {
            final ordersResult = await _ref.read(ordersRepositoryProvider).getOrdersByTech(techId);

            await ordersResult.when(
              left: (f) async => debugPrint('فشل جلب طلبات الفني لحساب التقييم: ${f.message}'),
              right: (allTechOrders) async {
                final ratedOrders = allTechOrders.where((o) => o.rating != null && o.rating! > 0).toList();

                if (ratedOrders.isNotEmpty) {
                  final double totalRating = ratedOrders.fold(0.0, (sum, item) => sum + item.rating!);
                  final double averageRating = totalRating / ratedOrders.length;
                  await _ref.read(techsRepositoryProvider).updateRating(techId, averageRating);
                  _ref.invalidate(techsStreamProvider);
                  _ref.invalidate(techniciansProvider);
                  _ref.invalidate(currentTechnicianProvider);
                }
              },
            );
          } catch (e) {
            debugPrint('خطأ أثناء تحديث تقييم الفني: $e');
          }
        }
        _ref.invalidate(ordersStreamProvider);
        _ref.invalidate(techniciansProvider);
        return Right(updatedOrder);
      },
    );
  }

  Future<Either<Failure, Technician>> addTechnician(CreateTechnicianDto dto) =>
      _ref.read(techsRepositoryProvider).addTechnician(dto);
      
  Future<Either<Failure, Technician>> updateTechnician(String id, UpdateTechnicianDto dto) => 
      _ref.read(techsRepositoryProvider).updateTechnician(id, dto);

  /// شحن محفظة الفني بواسطة الأدمن
  Future<Either<Failure, Technician>> rechargeTechWallet(String techId, int amount) async {
    try {
      final techResult = await _ref.read(techsRepositoryProvider).getTechnicianById(techId);

      return await techResult.when(
        left: (f) => Left(f),
        right: (tech) async {
          final newBalance = tech.walletBalance + amount;
          final updatedTech = await _ref.read(techsRepositoryProvider).update(techId, {
            'wallet_balance': newBalance,
          });
          _ref.invalidate(techsStreamProvider);
          _ref.invalidate(techniciansProvider);
          return Right(updatedTech);
        },
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteTechnician(String id) async {
    final result = await _ref.read(techsRepositoryProvider).deleteTechnician(id);
    _ref.invalidate(techsStreamProvider);
    _ref.invalidate(techniciansProvider);
    return result;
  }
      
  Future<Either<Failure, Order>> addOrderNotes(String id, String notes) =>
      _ref.read(ordersRepositoryProvider).addAdminNotes(id, notes);

  Future<Either<Failure, void>> deleteOrder(Order order) async {
    if (AdminBusinessRules.shouldFreeTechOnDelete(order) && order.techId != null) {
      await _ref.read(techsRepositoryProvider).updateTechStatus(order.techId!, TechStatus.available);
      _ref.invalidate(techsStreamProvider);
    }
    final result = await _ref.read(ordersRepositoryProvider).deleteOrder(order.id);
    _ref.invalidate(ordersStreamProvider);
    return result;
  }

  /// اعتماد طلب شحن محفظة وتحويل الرصيد تلقائياً للفني
  Future<Either<Failure, void>> approveWalletRechargeRequest(WalletRecharge recharge) async {
    try {
      final techResult = await _ref.read(techsRepositoryProvider).getTechnicianById(recharge.techId);
      await techResult.when(
        left: (f) => throw f.message,
        right: (tech) async {
          final newBalance = tech.walletBalance + recharge.amount;
          await _ref.read(techsRepositoryProvider).update(recharge.techId, {
            'wallet_balance': newBalance,
          });
        },
      );

      await Supabase.instance.client.from('wallet_recharges').update({
        'status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', recharge.id);

      _ref.invalidate(techsStreamProvider);
      _ref.invalidate(techniciansProvider);
      _ref.invalidate(walletRechargesStreamProvider);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  /// رفض طلب شحن المحفظة مع ذكر السبب
  Future<Either<Failure, void>> rejectWalletRechargeRequest(String rechargeId, {String? reason}) async {
    try {
      await Supabase.instance.client.from('wallet_recharges').update({
        'status': 'rejected',
        'rejection_reason': reason ?? 'تعذر التأكد من صحة إيصال التحويل',
      }).eq('id', rechargeId);

      _ref.invalidate(walletRechargesStreamProvider);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
