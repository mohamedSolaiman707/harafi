import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/failures.dart';
import '../../domain/business/admin_business_rules.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/order.dart';
import '../../domain/models/technician.dart';
import 'orders_provider.dart';
import 'techs_provider.dart';
import '../../../../core/either.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/whatsapp_otp_service.dart';

final adminActionsProvider = Provider<AdminActions>((ref) {
  return AdminActions(ref);
});

class AdminActions {
  final Ref _ref;
  AdminActions(this._ref);

  /// إنشاء طلب جديد (مع دعم تعيين فني مسبقاً)
  Future<Either<Failure, Order>> createOrder(Order order) async {
    try {
      final result = await _ref.read(ordersRepositoryProvider).create(order);
      
      if (order.techId != null && order.techId!.isNotEmpty) {
        await _ref.read(techsRepositoryProvider).updateTechStatus(order.techId!, TechStatus.busy);
        _ref.invalidate(techsStreamProvider);
      }
      
      _ref.invalidate(ordersStreamProvider);
      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  /// إنهاء الطلب وتحديث إحصائيات الفني (العمليات والأرباح)
  Future<Either<Failure, Order>> completeOrder(
    Order order, {
    int? finalPrice,
    String? techNotes,
    String? logMessage,
  }) async {
    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(
          order.id,
          OrderStatus.completed,
          finalPrice: finalPrice,
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
            final techResult = await _ref
                .read(techsRepositoryProvider)
                .getTechnicianById(techId);

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

  /// توثيق أو إلغاء توثيق فني
  Future<Either<Failure, Technician>> toggleVerification(String techId, bool status) async {
    try {
      final result = await _ref.read(techsRepositoryProvider).update(techId, {
        'is_verified': status,
      });
      _ref.invalidate(techsStreamProvider);
      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  /// شحن محفظة الفني بمبلغ محدد بواسطة الأدمن
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

  /// وظيفة تقييم الطلب وتحديث متوسط تقييم الفني
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

  Future<Either<Failure, Order>> assignTech(Order order, Technician tech) async {
    if (!AdminBusinessRules.canAssignTech(tech, order)) {
      return Left(BusinessException('الفني غير متاح حالياً'));
    }

    final assignment = await _ref
        .read(ordersRepositoryProvider)
        .assignTechnician(order.id, tech.id);

    return await assignment.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        await _ref.read(techsRepositoryProvider).updateTechStatus(tech.id, TechStatus.busy);
        
        // إرسال إشعار بالفني عبر الواتساب فور تعيينه للطلب
        WhatsAppOtpService.sendTechAssignmentNotification(tech: tech, order: updatedOrder);

        _ref.invalidate(techsStreamProvider);
        _ref.invalidate(ordersStreamProvider);
        return Right(updatedOrder);
      },
    );
  }

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

  /// رفض/اعتذار الفني عن الطلب مع إدراج سبب اختياري وإبلاغ العميل بواتساب
  Future<Either<Failure, Order>> rejectOrderByTech(
    Order order, {
    String? reason,
  }) async {
    final String cleanReason = reason?.trim() ?? '';
    final String logMessage = cleanReason.isNotEmpty
        ? 'اعتذر الفني عن استقبال الطلب. السبب: $cleanReason'
        : 'اعتذر الفني عن استقبال الطلب';

    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(
          order.id,
          OrderStatus.cancelled,
          techNotes: cleanReason.isNotEmpty ? 'سبب اعتذار الفني: $cleanReason' : 'اعتذر الفني عن استقبال الطلب',
          logMessage: logMessage,
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

        // إرسال إشعار اعتذار للعميل عبر الواتساب
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

  Future<Either<Failure, Technician>> addTechnician(CreateTechnicianDto dto) =>
      _ref.read(techsRepositoryProvider).addTechnician(dto);
      
  Future<Either<Failure, Technician>> updateTechnician(String id, UpdateTechnicianDto dto) => 
      _ref.read(techsRepositoryProvider).updateTechnician(id, dto);

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
}
