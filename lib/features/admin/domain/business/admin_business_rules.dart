import '../enums/order_status.dart';
import '../enums/tech_status.dart';
import '../models/order.dart';
import '../models/technician.dart';
import 'order_lifecycle.dart';

class AdminBusinessRules {
  static bool canAssignTech(Technician tech, Order order) {
    return tech.status == TechStatus.available && tech.spec == order.service;
  }

  static bool shouldFreeTech(OrderStatus newStatus) {
    return OrderLifecycle.isTerminal(newStatus);
  }

  static bool canDeleteTech(Technician tech, List<Order> orders) {
    return !orders.any(
      (order) => order.techId == tech.id && OrderLifecycle.requiresTechnician(order.status),
    );
  }

  static bool shouldFreeTechOnDelete(Order order) {
    return order.techId != null && OrderLifecycle.requiresTechnician(order.status);
  }

  static bool canMoveOrderTo(OrderStatus currentStatus, OrderStatus nextStatus) {
    return OrderLifecycle.canTransition(currentStatus, nextStatus);
  }
}
