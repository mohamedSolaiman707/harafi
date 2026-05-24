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

  Future<Either<Failure, Technician>> addTechnician(
    CreateTechnicianDto dto,
  ) async {
    return await _ref.read(techsRepositoryProvider).addTechnician(dto);
  }

  Future<Either<Failure, Technician>> updateTechnician(
    String id,
    UpdateTechnicianDto dto,
  ) async {
    return await _ref.read(techsRepositoryProvider).updateTechnician(id, dto);
  }

  Future<Either<Failure, void>> deleteTechnician(Technician tech) async {
    final orders = _ref.read(ordersProvider).valueOrNull ?? [];
    if (!AdminBusinessRules.canDeleteTech(tech, orders)) {
      return Left(
        BusinessException('لا يمكن حذف الفني بينما لديه طلبات جارية'),
      );
    }
    return await _ref.read(techsRepositoryProvider).deleteTechnician(tech.id);
  }

  Future<Either<Failure, Order>> assignTech(
    Order order,
    Technician tech,
  ) async {
    if (!AdminBusinessRules.canAssignTech(tech, order)) {
      return Left(
        BusinessException('الفني غير متاح أو تخصصه لا يتطابق مع الطلب'),
      );
    }

    final assignment = await _ref
        .read(ordersRepositoryProvider)
        .assignTechnician(order.id, tech.id);
        
    return await assignment.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        // تحديث حالة الفني لـ "مشغول" فور تعيينه
        await _ref.read(techsRepositoryProvider).updateTechStatus(tech.id, TechStatus.busy);
        return Right(updatedOrder);
      },
    );
  }

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
        if (order.techId != null) {
          await _ref.read(techsRepositoryProvider).updateTechStatus(order.techId!, TechStatus.available);
          await _ref.read(techsRepositoryProvider).incrementJobCount(order.techId!);
          if (finalPrice != null) {
            await _ref.read(techsRepositoryProvider).incrementEarnings(order.techId!, finalPrice);
          }
        }
        return Right(updatedOrder);
      },
    );
  }

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
        }
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
    return await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(order.id, status, logMessage: logMessage);
  }

  Future<Either<Failure, Order>> addOrderNotes(String orderId, String notes) async {
    return await _ref.read(ordersRepositoryProvider).addAdminNotes(orderId, notes);
  }

  Future<Either<Failure, Order>> rateOrder(String orderId, int rating) async {
    return await _ref.read(ordersRepositoryProvider).rateOrder(orderId, rating);
  }

  Future<Either<Failure, void>> deleteOrder(Order order) async {
    if (AdminBusinessRules.shouldFreeTechOnDelete(order) && order.techId != null) {
      await _ref.read(techsRepositoryProvider).updateTechStatus(order.techId!, TechStatus.available);
    }
    return await _ref.read(ordersRepositoryProvider).deleteOrder(order.id);
  }
}
