// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'technician.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Technician _$TechnicianFromJson(Map<String, dynamic> json) {
  return _Technician.fromJson(json);
}

/// @nodoc
mixin _$Technician {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  ServiceType get spec => throw _privateConstructorUsedError;
  @JsonKey(name: 'price_range')
  String? get priceRange => throw _privateConstructorUsedError;
  @JsonKey(name: 'visit_price')
  int get visitPrice => throw _privateConstructorUsedError;
  String? get area => throw _privateConstructorUsedError;
  TechStatus get status => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_jobs')
  int get totalJobs => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Technician to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Technician
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TechnicianCopyWith<Technician> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TechnicianCopyWith<$Res> {
  factory $TechnicianCopyWith(
    Technician value,
    $Res Function(Technician) then,
  ) = _$TechnicianCopyWithImpl<$Res, Technician>;
  @useResult
  $Res call({
    String id,
    String name,
    String phone,
    ServiceType spec,
    @JsonKey(name: 'price_range') String? priceRange,
    @JsonKey(name: 'visit_price') int visitPrice,
    String? area,
    TechStatus status,
    double rating,
    @JsonKey(name: 'total_jobs') int totalJobs,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$TechnicianCopyWithImpl<$Res, $Val extends Technician>
    implements $TechnicianCopyWith<$Res> {
  _$TechnicianCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Technician
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? spec = null,
    Object? priceRange = freezed,
    Object? visitPrice = null,
    Object? area = freezed,
    Object? status = null,
    Object? rating = null,
    Object? totalJobs = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            phone: null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String,
            spec: null == spec
                ? _value.spec
                : spec // ignore: cast_nullable_to_non_nullable
                      as ServiceType,
            priceRange: freezed == priceRange
                ? _value.priceRange
                : priceRange // ignore: cast_nullable_to_non_nullable
                      as String?,
            visitPrice: null == visitPrice
                ? _value.visitPrice
                : visitPrice // ignore: cast_nullable_to_non_nullable
                      as int,
            area: freezed == area
                ? _value.area
                : area // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TechStatus,
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as double,
            totalJobs: null == totalJobs
                ? _value.totalJobs
                : totalJobs // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TechnicianImplCopyWith<$Res>
    implements $TechnicianCopyWith<$Res> {
  factory _$$TechnicianImplCopyWith(
    _$TechnicianImpl value,
    $Res Function(_$TechnicianImpl) then,
  ) = __$$TechnicianImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String phone,
    ServiceType spec,
    @JsonKey(name: 'price_range') String? priceRange,
    @JsonKey(name: 'visit_price') int visitPrice,
    String? area,
    TechStatus status,
    double rating,
    @JsonKey(name: 'total_jobs') int totalJobs,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$TechnicianImplCopyWithImpl<$Res>
    extends _$TechnicianCopyWithImpl<$Res, _$TechnicianImpl>
    implements _$$TechnicianImplCopyWith<$Res> {
  __$$TechnicianImplCopyWithImpl(
    _$TechnicianImpl _value,
    $Res Function(_$TechnicianImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Technician
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? spec = null,
    Object? priceRange = freezed,
    Object? visitPrice = null,
    Object? area = freezed,
    Object? status = null,
    Object? rating = null,
    Object? totalJobs = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$TechnicianImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        phone: null == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String,
        spec: null == spec
            ? _value.spec
            : spec // ignore: cast_nullable_to_non_nullable
                  as ServiceType,
        priceRange: freezed == priceRange
            ? _value.priceRange
            : priceRange // ignore: cast_nullable_to_non_nullable
                  as String?,
        visitPrice: null == visitPrice
            ? _value.visitPrice
            : visitPrice // ignore: cast_nullable_to_non_nullable
                  as int,
        area: freezed == area
            ? _value.area
            : area // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TechStatus,
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as double,
        totalJobs: null == totalJobs
            ? _value.totalJobs
            : totalJobs // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TechnicianImpl implements _Technician {
  const _$TechnicianImpl({
    required this.id,
    required this.name,
    required this.phone,
    required this.spec,
    @JsonKey(name: 'price_range') this.priceRange,
    @JsonKey(name: 'visit_price') this.visitPrice = 50,
    this.area,
    this.status = TechStatus.available,
    this.rating = 0.0,
    @JsonKey(name: 'total_jobs') this.totalJobs = 0,
    @JsonKey(name: 'created_at') required this.createdAt,
  });

  factory _$TechnicianImpl.fromJson(Map<String, dynamic> json) =>
      _$$TechnicianImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String phone;
  @override
  final ServiceType spec;
  @override
  @JsonKey(name: 'price_range')
  final String? priceRange;
  @override
  @JsonKey(name: 'visit_price')
  final int visitPrice;
  @override
  final String? area;
  @override
  @JsonKey()
  final TechStatus status;
  @override
  @JsonKey()
  final double rating;
  @override
  @JsonKey(name: 'total_jobs')
  final int totalJobs;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'Technician(id: $id, name: $name, phone: $phone, spec: $spec, priceRange: $priceRange, visitPrice: $visitPrice, area: $area, status: $status, rating: $rating, totalJobs: $totalJobs, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TechnicianImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.spec, spec) || other.spec == spec) &&
            (identical(other.priceRange, priceRange) ||
                other.priceRange == priceRange) &&
            (identical(other.visitPrice, visitPrice) ||
                other.visitPrice == visitPrice) &&
            (identical(other.area, area) || other.area == area) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalJobs, totalJobs) ||
                other.totalJobs == totalJobs) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    phone,
    spec,
    priceRange,
    visitPrice,
    area,
    status,
    rating,
    totalJobs,
    createdAt,
  );

  /// Create a copy of Technician
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TechnicianImplCopyWith<_$TechnicianImpl> get copyWith =>
      __$$TechnicianImplCopyWithImpl<_$TechnicianImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TechnicianImplToJson(this);
  }
}

abstract class _Technician implements Technician {
  const factory _Technician({
    required final String id,
    required final String name,
    required final String phone,
    required final ServiceType spec,
    @JsonKey(name: 'price_range') final String? priceRange,
    @JsonKey(name: 'visit_price') final int visitPrice,
    final String? area,
    final TechStatus status,
    final double rating,
    @JsonKey(name: 'total_jobs') final int totalJobs,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$TechnicianImpl;

  factory _Technician.fromJson(Map<String, dynamic> json) =
      _$TechnicianImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get phone;
  @override
  ServiceType get spec;
  @override
  @JsonKey(name: 'price_range')
  String? get priceRange;
  @override
  @JsonKey(name: 'visit_price')
  int get visitPrice;
  @override
  String? get area;
  @override
  TechStatus get status;
  @override
  double get rating;
  @override
  @JsonKey(name: 'total_jobs')
  int get totalJobs;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of Technician
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TechnicianImplCopyWith<_$TechnicianImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
