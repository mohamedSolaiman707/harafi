class TechStats {
  final int total;
  final int available;
  final int busy;

  TechStats({required this.total, required this.available, required this.busy});
}

class DashboardStats {
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int totalTechs;
  final int availableTechs;
  final int busyTechs;
  final int onLeaveTechs;

  DashboardStats({
    required this.totalOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalTechs,
    required this.availableTechs,
    required this.busyTechs,
    required this.onLeaveTechs,
  });
}
