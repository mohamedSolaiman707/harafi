abstract class Either<L, R> {
  const Either();

  T when<T>({
    required T Function(L left) left,
    required T Function(R right) right,
  });

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  R? getRight() {
    return when(
      left: (_) => null,
      right: (r) => r,
    );
  }

  L? getLeft() {
    return when(
      left: (l) => l,
      right: (_) => null,
    );
  }
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T when<T>({
    required T Function(L left) left,
    required T Function(R right) right,
  }) {
    return left(value);
  }
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T when<T>({
    required T Function(L left) left,
    required T Function(R right) right,
  }) {
    return right(value);
  }
}
