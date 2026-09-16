import '../enums/order_status.dart';

enum OrderLifecyclePhase {
  newRequest,
  awaitingTechnicianResponse,
  technicianAccepted,
  technicianOnTheWay,
  technicianArrived,
  inProgress,
  readyToComplete,
  completed,
  cancelled,
}

class OrderLifecycle {
  static OrderLifecyclePhase fromStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return OrderLifecyclePhase.newRequest;
      case OrderStatus.assigned:
        return OrderLifecyclePhase.awaitingTechnicianResponse;
      case OrderStatus.onTheWay:
        return OrderLifecyclePhase.technicianOnTheWay;
      case OrderStatus.started:
        return OrderLifecyclePhase.inProgress;
      case OrderStatus.completed:
        return OrderLifecyclePhase.completed;
      case OrderStatus.cancelled:
        return OrderLifecyclePhase.cancelled;
    }
  }

  static bool isActive(OrderStatus status) => !isTerminal(status);

  static bool isTerminal(OrderStatus status) {
    return status == OrderStatus.completed || status == OrderStatus.cancelled;
  }

  static bool requiresTechnician(OrderStatus status) {
    return status == OrderStatus.assigned ||
        status == OrderStatus.onTheWay ||
        status == OrderStatus.started;
  }

  static bool canTransition(OrderStatus current, OrderStatus next) {
    if (current == next) return true;
    if (isTerminal(current)) return false;

    switch (current) {
      case OrderStatus.pending:
        return next == OrderStatus.assigned || next == OrderStatus.cancelled;
      case OrderStatus.assigned:
        return next == OrderStatus.onTheWay || next == OrderStatus.cancelled;
      case OrderStatus.onTheWay:
        return next == OrderStatus.started || next == OrderStatus.cancelled;
      case OrderStatus.started:
        return next == OrderStatus.completed || next == OrderStatus.cancelled;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return false;
    }
  }
}
