import '../models/order.dart';
import '../models/technician.dart';
import '../enums/order_status.dart';
import '../enums/tech_status.dart';

class AdminBusinessRules {
  static bool canAssignTech(Technician tech, Order order) {
    return tech.status == TechStatus.available && tech.spec == order.service;
  }

  static bool shouldFreeTech(OrderStatus newStatus) {
    return newStatus == OrderStatus.completed ||
        newStatus == OrderStatus.cancelled;
  }

  static bool canDeleteTech(Technician tech, List<Order> orders) {
    return !orders.any(
      (o) => o.techId == tech.id && o.status == OrderStatus.pending,
    );
  }

  static bool shouldFreeTechOnDelete(Order order) {
    return order.techId != null && order.status == OrderStatus.pending;
  }
}
