class DashboardStats {
  final int totalOrders;
  final int pendingOrders;
  final int activeOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int totalRevenue; // جديد: إجمالي المبالغ المحصلة
  final int totalTechs;
  final int availableTechs;
  final int busyTechs;
  final int onLeaveTechs;
  final int pendingTechs;

  DashboardStats({
    required this.totalOrders,
    required this.pendingOrders,
    required this.activeOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalRevenue,
    required this.totalTechs,
    required this.availableTechs,
    required this.busyTechs,
    required this.onLeaveTechs,
    required this.pendingTechs,
  });
}
