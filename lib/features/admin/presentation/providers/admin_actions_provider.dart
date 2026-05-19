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
        final techUpdate = await _ref
            .read(techsRepositoryProvider)
            .updateTechStatus(tech.id, TechStatus.busy);
        return techUpdate.when(
          left: (failure) => Left(failure),
          right: (_) => Right(updatedOrder),
        );
      },
    );
  }

  Future<Either<Failure, Order>> completeOrder(Order order) async {
    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(order.id, OrderStatus.completed);
    return await statusResult.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        if (order.techId != null) {
          final freeTech = await _ref
              .read(techsRepositoryProvider)
              .updateTechStatus(order.techId!, TechStatus.available);
          if (freeTech.isLeft)
            return Left(
              freeTech.when(
                left: (f) => f,
                right: (_) => throw StateError('unexpected'),
              ),
            );
          final incrementResult = await _ref
              .read(techsRepositoryProvider)
              .incrementJobCount(order.techId!);
          return incrementResult.when(
            left: (failure) => Left(failure),
            right: (_) => Right(updatedOrder),
          );
        }
        return Right(updatedOrder);
      },
    );
  }

  Future<Either<Failure, Order>> cancelOrder(Order order) async {
    final statusResult = await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(order.id, OrderStatus.cancelled);
    return await statusResult.when(
      left: (failure) => Left(failure),
      right: (updatedOrder) async {
        if (order.techId != null) {
          final freeTech = await _ref
              .read(techsRepositoryProvider)
              .updateTechStatus(order.techId!, TechStatus.available);
          return freeTech.when(
            left: (failure) => Left(failure),
            right: (_) => Right(updatedOrder),
          );
        }
        return Right(updatedOrder);
      },
    );
  }

  Future<Either<Failure, Order>> updateOrderStatus(
    Order order,
    OrderStatus status,
  ) async {
    if (status == OrderStatus.completed) {
      return await completeOrder(order);
    }
    if (status == OrderStatus.cancelled) {
      return await cancelOrder(order);
    }
    return await _ref
        .read(ordersRepositoryProvider)
        .updateOrderStatus(order.id, status);
  }

  Future<Either<Failure, Order>> addOrderNotes(
    String orderId,
    String notes,
  ) async {
    return await _ref
        .read(ordersRepositoryProvider)
        .addAdminNotes(orderId, notes);
  }

  Future<Either<Failure, Order>> rateOrder(String orderId, int rating) async {
    return await _ref.read(ordersRepositoryProvider).rateOrder(orderId, rating);
  }

  Future<Either<Failure, void>> deleteOrder(Order order) async {
    if (AdminBusinessRules.shouldFreeTechOnDelete(order) &&
        order.techId != null) {
      final freeTech = await _ref
          .read(techsRepositoryProvider)
          .updateTechStatus(order.techId!, TechStatus.available);
      if (freeTech.isLeft)
        return Left(
          freeTech.when(
            left: (f) => f,
            right: (_) => throw StateError('unexpected'),
          ),
        );
    }
    return await _ref.read(ordersRepositoryProvider).deleteOrder(order.id);
  }
}
