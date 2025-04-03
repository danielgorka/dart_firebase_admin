// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'firestore.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Settings {
  /// The database name. If omitted, the default database will be used.
  String? get databaseId;

  /// Whether to use `BigInt` for integer types when deserializing Firestore
  /// Documents. Regardless of magnitude, all integer values are returned as
  /// `BigInt` to match the precision of the Firestore backend. Floating point
  /// numbers continue to use JavaScript's `number` type.
  bool? get useBigInt;

  /// Create a copy of Settings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsCopyWith<Settings> get copyWith =>
      _$SettingsCopyWithImpl<Settings>(this as Settings, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Settings &&
            (identical(other.databaseId, databaseId) ||
                other.databaseId == databaseId) &&
            (identical(other.useBigInt, useBigInt) ||
                other.useBigInt == useBigInt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, databaseId, useBigInt);

  @override
  String toString() {
    return 'Settings(databaseId: $databaseId, useBigInt: $useBigInt)';
  }
}

/// @nodoc
abstract mixin class $SettingsCopyWith<$Res> {
  factory $SettingsCopyWith(Settings value, $Res Function(Settings) _then) =
      _$SettingsCopyWithImpl;
  @useResult
  $Res call({String? databaseId, bool? useBigInt});
}

/// @nodoc
class _$SettingsCopyWithImpl<$Res> implements $SettingsCopyWith<$Res> {
  _$SettingsCopyWithImpl(this._self, this._then);

  final Settings _self;
  final $Res Function(Settings) _then;

  /// Create a copy of Settings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? databaseId = freezed,
    Object? useBigInt = freezed,
  }) {
    return _then(_self.copyWith(
      databaseId: freezed == databaseId
          ? _self.databaseId
          : databaseId // ignore: cast_nullable_to_non_nullable
              as String?,
      useBigInt: freezed == useBigInt
          ? _self.useBigInt
          : useBigInt // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc

class _Settings implements Settings {
  _Settings({this.databaseId, this.useBigInt});

  /// The database name. If omitted, the default database will be used.
  @override
  final String? databaseId;

  /// Whether to use `BigInt` for integer types when deserializing Firestore
  /// Documents. Regardless of magnitude, all integer values are returned as
  /// `BigInt` to match the precision of the Firestore backend. Floating point
  /// numbers continue to use JavaScript's `number` type.
  @override
  final bool? useBigInt;

  /// Create a copy of Settings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SettingsCopyWith<_Settings> get copyWith =>
      __$SettingsCopyWithImpl<_Settings>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Settings &&
            (identical(other.databaseId, databaseId) ||
                other.databaseId == databaseId) &&
            (identical(other.useBigInt, useBigInt) ||
                other.useBigInt == useBigInt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, databaseId, useBigInt);

  @override
  String toString() {
    return 'Settings(databaseId: $databaseId, useBigInt: $useBigInt)';
  }
}

/// @nodoc
abstract mixin class _$SettingsCopyWith<$Res>
    implements $SettingsCopyWith<$Res> {
  factory _$SettingsCopyWith(_Settings value, $Res Function(_Settings) _then) =
      __$SettingsCopyWithImpl;
  @override
  @useResult
  $Res call({String? databaseId, bool? useBigInt});
}

/// @nodoc
class __$SettingsCopyWithImpl<$Res> implements _$SettingsCopyWith<$Res> {
  __$SettingsCopyWithImpl(this._self, this._then);

  final _Settings _self;
  final $Res Function(_Settings) _then;

  /// Create a copy of Settings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? databaseId = freezed,
    Object? useBigInt = freezed,
  }) {
    return _then(_Settings(
      databaseId: freezed == databaseId
          ? _self.databaseId
          : databaseId // ignore: cast_nullable_to_non_nullable
              as String?,
      useBigInt: freezed == useBigInt
          ? _self.useBigInt
          : useBigInt // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
mixin _$QueryOptions<T> {
  _ResourcePath get parentPath;
  String get collectionId;
  _FirestoreDataConverter<T> get converter;
  bool get allDescendants;
  List<_FilterInternal> get filters;
  List<_FieldOrder> get fieldOrders;
  _QueryCursor? get startAt;
  _QueryCursor? get endAt;
  int? get limit;
  firestore1.StructuredQuery_Projection? get projection;
  LimitType? get limitType;
  int?
      get offset; // Whether to select all documents under `parentPath`. By default, only
// collections that match `collectionId` are selected.
  bool
      get kindless; // Whether to require consistent documents when restarting the query. By
// default, restarting the query uses the readTime offset of the original
// query to provide consistent results.
  bool get requireConsistency;

  /// Create a copy of _QueryOptions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$QueryOptionsCopyWith<T, _QueryOptions<T>> get copyWith =>
      __$QueryOptionsCopyWithImpl<T, _QueryOptions<T>>(
          this as _QueryOptions<T>, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _QueryOptions<T> &&
            (identical(other.parentPath, parentPath) ||
                other.parentPath == parentPath) &&
            (identical(other.collectionId, collectionId) ||
                other.collectionId == collectionId) &&
            (identical(other.converter, converter) ||
                other.converter == converter) &&
            (identical(other.allDescendants, allDescendants) ||
                other.allDescendants == allDescendants) &&
            const DeepCollectionEquality().equals(other.filters, filters) &&
            const DeepCollectionEquality()
                .equals(other.fieldOrders, fieldOrders) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.projection, projection) ||
                other.projection == projection) &&
            (identical(other.limitType, limitType) ||
                other.limitType == limitType) &&
            (identical(other.offset, offset) || other.offset == offset) &&
            (identical(other.kindless, kindless) ||
                other.kindless == kindless) &&
            (identical(other.requireConsistency, requireConsistency) ||
                other.requireConsistency == requireConsistency));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      parentPath,
      collectionId,
      converter,
      allDescendants,
      const DeepCollectionEquality().hash(filters),
      const DeepCollectionEquality().hash(fieldOrders),
      startAt,
      endAt,
      limit,
      projection,
      limitType,
      offset,
      kindless,
      requireConsistency);

  @override
  String toString() {
    return '_QueryOptions<$T>(parentPath: $parentPath, collectionId: $collectionId, converter: $converter, allDescendants: $allDescendants, filters: $filters, fieldOrders: $fieldOrders, startAt: $startAt, endAt: $endAt, limit: $limit, projection: $projection, limitType: $limitType, offset: $offset, kindless: $kindless, requireConsistency: $requireConsistency)';
  }
}

/// @nodoc
abstract mixin class _$QueryOptionsCopyWith<T, $Res> {
  factory _$QueryOptionsCopyWith(
          _QueryOptions<T> value, $Res Function(_QueryOptions<T>) _then) =
      __$QueryOptionsCopyWithImpl;
  @useResult
  $Res call(
      {_ResourcePath parentPath,
      String collectionId,
      ({
        T Function(QueryDocumentSnapshot<Map<String, Object?>>) fromFirestore,
        Map<String, Object?> Function(T) toFirestore
      }) converter,
      bool allDescendants,
      List<_FilterInternal> filters,
      List<_FieldOrder> fieldOrders,
      _QueryCursor? startAt,
      _QueryCursor? endAt,
      int? limit,
      firestore1.StructuredQuery_Projection? projection,
      LimitType? limitType,
      int? offset,
      bool kindless,
      bool requireConsistency});
}

/// @nodoc
class __$QueryOptionsCopyWithImpl<T, $Res>
    implements _$QueryOptionsCopyWith<T, $Res> {
  __$QueryOptionsCopyWithImpl(this._self, this._then);

  final _QueryOptions<T> _self;
  final $Res Function(_QueryOptions<T>) _then;

  /// Create a copy of _QueryOptions
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? parentPath = null,
    Object? collectionId = null,
    Object? converter = null,
    Object? allDescendants = null,
    Object? filters = null,
    Object? fieldOrders = null,
    Object? startAt = freezed,
    Object? endAt = freezed,
    Object? limit = freezed,
    Object? projection = freezed,
    Object? limitType = freezed,
    Object? offset = freezed,
    Object? kindless = null,
    Object? requireConsistency = null,
  }) {
    return _then(_self.copyWith(
      parentPath: null == parentPath
          ? _self.parentPath
          : parentPath // ignore: cast_nullable_to_non_nullable
              as _ResourcePath,
      collectionId: null == collectionId
          ? _self.collectionId
          : collectionId // ignore: cast_nullable_to_non_nullable
              as String,
      converter: null == converter
          ? _self.converter
          : converter // ignore: cast_nullable_to_non_nullable
              as ({
              T Function(
                  QueryDocumentSnapshot<Map<String, Object?>>) fromFirestore,
              Map<String, Object?> Function(T) toFirestore
            }),
      allDescendants: null == allDescendants
          ? _self.allDescendants
          : allDescendants // ignore: cast_nullable_to_non_nullable
              as bool,
      filters: null == filters
          ? _self.filters
          : filters // ignore: cast_nullable_to_non_nullable
              as List<_FilterInternal>,
      fieldOrders: null == fieldOrders
          ? _self.fieldOrders
          : fieldOrders // ignore: cast_nullable_to_non_nullable
              as List<_FieldOrder>,
      startAt: freezed == startAt
          ? _self.startAt
          : startAt // ignore: cast_nullable_to_non_nullable
              as _QueryCursor?,
      endAt: freezed == endAt
          ? _self.endAt
          : endAt // ignore: cast_nullable_to_non_nullable
              as _QueryCursor?,
      limit: freezed == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int?,
      projection: freezed == projection
          ? _self.projection
          : projection // ignore: cast_nullable_to_non_nullable
              as firestore1.StructuredQuery_Projection?,
      limitType: freezed == limitType
          ? _self.limitType
          : limitType // ignore: cast_nullable_to_non_nullable
              as LimitType?,
      offset: freezed == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int?,
      kindless: null == kindless
          ? _self.kindless
          : kindless // ignore: cast_nullable_to_non_nullable
              as bool,
      requireConsistency: null == requireConsistency
          ? _self.requireConsistency
          : requireConsistency // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class __QueryOptions<T> extends _QueryOptions<T> {
  __QueryOptions(
      {required this.parentPath,
      required this.collectionId,
      required this.converter,
      required this.allDescendants,
      required final List<_FilterInternal> filters,
      required final List<_FieldOrder> fieldOrders,
      this.startAt,
      this.endAt,
      this.limit,
      this.projection,
      this.limitType,
      this.offset,
      this.kindless = false,
      this.requireConsistency = true})
      : _filters = filters,
        _fieldOrders = fieldOrders,
        super._();

  @override
  final _ResourcePath parentPath;
  @override
  final String collectionId;
  @override
  final ({
    T Function(QueryDocumentSnapshot<Map<String, Object?>>) fromFirestore,
    Map<String, Object?> Function(T) toFirestore
  }) converter;
  @override
  final bool allDescendants;
  final List<_FilterInternal> _filters;
  @override
  List<_FilterInternal> get filters {
    if (_filters is EqualUnmodifiableListView) return _filters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filters);
  }

  final List<_FieldOrder> _fieldOrders;
  @override
  List<_FieldOrder> get fieldOrders {
    if (_fieldOrders is EqualUnmodifiableListView) return _fieldOrders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fieldOrders);
  }

  @override
  final _QueryCursor? startAt;
  @override
  final _QueryCursor? endAt;
  @override
  final int? limit;
  @override
  final firestore1.StructuredQuery_Projection? projection;
  @override
  final LimitType? limitType;
  @override
  final int? offset;
// Whether to select all documents under `parentPath`. By default, only
// collections that match `collectionId` are selected.
  @override
  @JsonKey()
  final bool kindless;
// Whether to require consistent documents when restarting the query. By
// default, restarting the query uses the readTime offset of the original
// query to provide consistent results.
  @override
  @JsonKey()
  final bool requireConsistency;

  /// Create a copy of _QueryOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$_QueryOptionsCopyWith<T, __QueryOptions<T>> get copyWith =>
      __$_QueryOptionsCopyWithImpl<T, __QueryOptions<T>>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is __QueryOptions<T> &&
            (identical(other.parentPath, parentPath) ||
                other.parentPath == parentPath) &&
            (identical(other.collectionId, collectionId) ||
                other.collectionId == collectionId) &&
            (identical(other.converter, converter) ||
                other.converter == converter) &&
            (identical(other.allDescendants, allDescendants) ||
                other.allDescendants == allDescendants) &&
            const DeepCollectionEquality().equals(other._filters, _filters) &&
            const DeepCollectionEquality()
                .equals(other._fieldOrders, _fieldOrders) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.projection, projection) ||
                other.projection == projection) &&
            (identical(other.limitType, limitType) ||
                other.limitType == limitType) &&
            (identical(other.offset, offset) || other.offset == offset) &&
            (identical(other.kindless, kindless) ||
                other.kindless == kindless) &&
            (identical(other.requireConsistency, requireConsistency) ||
                other.requireConsistency == requireConsistency));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      parentPath,
      collectionId,
      converter,
      allDescendants,
      const DeepCollectionEquality().hash(_filters),
      const DeepCollectionEquality().hash(_fieldOrders),
      startAt,
      endAt,
      limit,
      projection,
      limitType,
      offset,
      kindless,
      requireConsistency);

  @override
  String toString() {
    return '_QueryOptions<$T>(parentPath: $parentPath, collectionId: $collectionId, converter: $converter, allDescendants: $allDescendants, filters: $filters, fieldOrders: $fieldOrders, startAt: $startAt, endAt: $endAt, limit: $limit, projection: $projection, limitType: $limitType, offset: $offset, kindless: $kindless, requireConsistency: $requireConsistency)';
  }
}

/// @nodoc
abstract mixin class _$_QueryOptionsCopyWith<T, $Res>
    implements _$QueryOptionsCopyWith<T, $Res> {
  factory _$_QueryOptionsCopyWith(
          __QueryOptions<T> value, $Res Function(__QueryOptions<T>) _then) =
      __$_QueryOptionsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {_ResourcePath parentPath,
      String collectionId,
      ({
        T Function(QueryDocumentSnapshot<Map<String, Object?>>) fromFirestore,
        Map<String, Object?> Function(T) toFirestore
      }) converter,
      bool allDescendants,
      List<_FilterInternal> filters,
      List<_FieldOrder> fieldOrders,
      _QueryCursor? startAt,
      _QueryCursor? endAt,
      int? limit,
      firestore1.StructuredQuery_Projection? projection,
      LimitType? limitType,
      int? offset,
      bool kindless,
      bool requireConsistency});
}

/// @nodoc
class __$_QueryOptionsCopyWithImpl<T, $Res>
    implements _$_QueryOptionsCopyWith<T, $Res> {
  __$_QueryOptionsCopyWithImpl(this._self, this._then);

  final __QueryOptions<T> _self;
  final $Res Function(__QueryOptions<T>) _then;

  /// Create a copy of _QueryOptions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? parentPath = null,
    Object? collectionId = null,
    Object? converter = null,
    Object? allDescendants = null,
    Object? filters = null,
    Object? fieldOrders = null,
    Object? startAt = freezed,
    Object? endAt = freezed,
    Object? limit = freezed,
    Object? projection = freezed,
    Object? limitType = freezed,
    Object? offset = freezed,
    Object? kindless = null,
    Object? requireConsistency = null,
  }) {
    return _then(__QueryOptions<T>(
      parentPath: null == parentPath
          ? _self.parentPath
          : parentPath // ignore: cast_nullable_to_non_nullable
              as _ResourcePath,
      collectionId: null == collectionId
          ? _self.collectionId
          : collectionId // ignore: cast_nullable_to_non_nullable
              as String,
      converter: null == converter
          ? _self.converter
          : converter // ignore: cast_nullable_to_non_nullable
              as ({
              T Function(
                  QueryDocumentSnapshot<Map<String, Object?>>) fromFirestore,
              Map<String, Object?> Function(T) toFirestore
            }),
      allDescendants: null == allDescendants
          ? _self.allDescendants
          : allDescendants // ignore: cast_nullable_to_non_nullable
              as bool,
      filters: null == filters
          ? _self._filters
          : filters // ignore: cast_nullable_to_non_nullable
              as List<_FilterInternal>,
      fieldOrders: null == fieldOrders
          ? _self._fieldOrders
          : fieldOrders // ignore: cast_nullable_to_non_nullable
              as List<_FieldOrder>,
      startAt: freezed == startAt
          ? _self.startAt
          : startAt // ignore: cast_nullable_to_non_nullable
              as _QueryCursor?,
      endAt: freezed == endAt
          ? _self.endAt
          : endAt // ignore: cast_nullable_to_non_nullable
              as _QueryCursor?,
      limit: freezed == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int?,
      projection: freezed == projection
          ? _self.projection
          : projection // ignore: cast_nullable_to_non_nullable
              as firestore1.StructuredQuery_Projection?,
      limitType: freezed == limitType
          ? _self.limitType
          : limitType // ignore: cast_nullable_to_non_nullable
              as LimitType?,
      offset: freezed == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int?,
      kindless: null == kindless
          ? _self.kindless
          : kindless // ignore: cast_nullable_to_non_nullable
              as bool,
      requireConsistency: null == requireConsistency
          ? _self.requireConsistency
          : requireConsistency // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
