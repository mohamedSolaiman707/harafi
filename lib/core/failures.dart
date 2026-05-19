abstract class Failure {
  final String message;
  const Failure(this.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class BusinessException extends Failure {
  const BusinessException(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}
