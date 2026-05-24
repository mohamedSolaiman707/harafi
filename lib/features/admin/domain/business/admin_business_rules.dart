import '../models/order.dart';
import '../models/technician.dart';
import '../enums/order_status.dart';
import '../enums/tech_status.dart';

class AdminBusinessRules {
  // هل يمكن تعيين هذا الفني لهذا الطلب؟
  static bool canAssignTech(Technician tech, Order order) {
    return tech.status == TechStatus.available && tech.spec == order.service;
  }

  // هل هذه الحالة تعني أن الفني أصبح حراً الآن؟
  static bool shouldFreeTech(OrderStatus newStatus) {
    return newStatus == OrderStatus.completed ||
        newStatus == OrderStatus.cancelled;
  }

  // هل يمكن حذف هذا الفني من السيستم؟
  static bool canDeleteTech(Technician tech, List<Order> orders) {
    // لا يمكن حذف فني لديه طلبات (مُعينة، في الطريق، أو بدأ فيها)
    return !orders.any(
      (o) => o.techId == tech.id && 
      [OrderStatus.assigned, OrderStatus.onTheWay, OrderStatus.started].contains(o.status),
    );
  }

  // هل يجب تحرير الفني عند حذف الطلب؟
  static bool shouldFreeTechOnDelete(Order order) {
    // إذا حُذف الطلب وهو في حالة "نشطة"، يجب إعادة الفني لحالة "متاح"
    return order.techId != null && 
      [OrderStatus.assigned, OrderStatus.onTheWay, OrderStatus.started].contains(order.status);
  }
}
