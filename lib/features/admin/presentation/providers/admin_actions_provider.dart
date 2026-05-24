import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/business/admin_business_rules.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/order.dart';
import '../../domain/models/technician.dart';
import 'orders_provider.dart';
import 'techs_provider.dart';
import '../../../../core/either.dart';
import '../../../../core/failures.dart';

final adminActionsProvider = Provider<AdminActions>((ref) {
  return AdminActions(ref);
});

class AdminActions {
  final Ref _ref;
  AdminActions(this._ref);

  /// وظيفة إنهاء الطلب وتحديث إحصائيات الفني (العمليات والأرباح)
  Future<Either<Failure, Order>> completeOrder(
    Order order, {
    int? finalPrice,
    String? techNotes,
    String? logMessage,
  }) async {
    // 1. تحديث حالة الطلب أولاً في جدول الـ Orders
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
            // 2. جلب أحدث بيانات للفني من الداتابيز لضمان صحة العدادات
            final techResult = await _ref.read(techsRepositoryProvider).getTechnicianById(techId);
            
            await techResult.when(
              left: (f) => debugPrint('فشل جلب الفني لتحديث إحصائياته: ${f.message}'),
              right: (tech) async {
                // 3. التحديث الأهم: زيادة عدد العمليات + زيادة الأرباح + تغيير الحالة لمتاح
                await _ref.read(techsRepositoryProvider).update(techId, {
                  'status': TechStatus.available.label,
                  'total_jobs': tech.totalJobs + 1,
                  'total_earnings': tech.totalEarnings + (finalPrice ?? 0),
                  'phone': tech.phone, // لضمان عمل الـ Fallback في الريبوزيتوري
                });
                
                // 4. تحديث الواجهة فوراً (Invalidate Providers)
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

  /// وظيفة تعيين فني (وتحويل حالته لمشغول)
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
        _ref.invalidate(techsStreamProvider);
        _ref.invalidate(ordersStreamProvider);
        return Right(updatedOrder);
      },
    );
  }

  /// وظيفة إلغاء الطلب (وتحرير الفني)
  Future<Either<Failure, Order>> cancelOrder(Order order, {String? logMessage}) async {
    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(
          order.id, 
          OrderStatus.cancelled,
          logMessage: logMessage,
        );
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

  /// تحديث الحالة (توجيه للوظيفة المناسبة)
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

    // للحالات الوسطى (في الطريق، بدأ العمل)
    final result = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(order.id, status, logMessage: logMessage);
        
    _ref.invalidate(ordersStreamProvider);
    return result;
  }

  // باقي الدوال الإدارية
  Future<Either<Failure, Technician>> addTechnician(CreateTechnicianDto dto) => _ref.read(techsRepositoryProvider).addTechnician(dto);
  Future<Either<Failure, Technician>> updateTechnician(String id, UpdateTechnicianDto dto) => _ref.read(techsRepositoryProvider).updateTechnician(id, dto);
  Future<Either<Failure, Order>> addOrderNotes(String id, String notes) => _ref.read(ordersRepositoryProvider).addAdminNotes(id, notes);
  Future<Either<Failure, Order>> rateOrder(String id, int rating) => _ref.read(ordersRepositoryProvider).rateOrder(id, rating);
  
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
