class DashboardStats {
  final int totalOrders;
  final int pendingOrders;   // طلبات جديدة بانتظار التعيين
  final int activeOrders;    // طلبات قيد التنفيذ (Assigned, On Way, Started)
  final int completedOrders;
  final int cancelledOrders;
  final int totalTechs;
  final int availableTechs;
  final int busyTechs;
  final int onLeaveTechs;
  final int pendingTechs;    // فنيين بانتظار الاعتماد

  DashboardStats({
    required this.totalOrders,
    required this.pendingOrders,
    required this.activeOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalTechs,
    required this.availableTechs,
    required this.busyTechs,
    required this.onLeaveTechs,
    required this.pendingTechs,
  });
}
