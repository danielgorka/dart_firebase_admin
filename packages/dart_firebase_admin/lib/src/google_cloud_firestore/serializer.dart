part of 'firestore.dart';

/// A type representing the raw Firestore document data.
typedef DocumentData = Map<String, Object?>;

@internal
typedef ApiMapValue = Map<String, firestore1.Value>;

abstract base class _Serializable {
  firestore1.Value _toProto();
}

class _Serializer {
  _Serializer(this.firestore);

  final Firestore firestore;

  Object _createInteger(fixnum.Int64 n) {
    if (firestore._settings.useBigInt ?? false) {
      return BigInt.parse(n.toString());
    } else {
      return n.toInt();
    }
  }

  /// Encodes a Dart object into the Firestore 'Fields' representation.
  firestore1.MapValue encodeFields(DocumentData obj) {
    return firestore1.MapValue(
      fields: obj.map((key, value) {
        return MapEntry(key, encodeValue(value));
      }).whereValueNotNull(),
    );
  }

  /// Encodes a Dart value into the Firestore 'Value' representation.
  firestore1.Value? encodeValue(Object? value) {
    switch (value) {
      case _FieldTransform():
        return null;

      case String():
        return firestore1.Value(stringValue: value);

      case bool():
        return firestore1.Value(booleanValue: value);

      case int():
        return firestore1.Value(integerValue: fixnum.Int64(value));
      case BigInt():
        return firestore1.Value(
          integerValue: fixnum.Int64.parseInt(value.toString()),
        );

      case double():
        return firestore1.Value(doubleValue: value);

      case DateTime():
        final timestamp = Timestamp.fromDate(value);
        return timestamp._toProto();

      case null:
        return firestore1.Value(
          nullValue: google_protobuf.NullValue.NULL_VALUE,
        );

      case _Serializable():
        return value._toProto();

      case List():
        return firestore1.Value(
          arrayValue: firestore1.ArrayValue(
            values: value.map(encodeValue).nonNulls.toList(),
          ),
        );

      case Map():
        if (value.isEmpty) {
          return firestore1.Value(
            mapValue: firestore1.MapValue(fields: {}),
          );
        }

        final fields = encodeFields(Map.from(value));
        if (fields.fields.isEmpty) return null;

        return firestore1.Value(mapValue: fields);

      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported field value: ${value.runtimeType}',
        );
    }
  }

  /// Decodes a single Firestore 'Value' Protobuf.
  Object? decodeValue(Object? proto) {
    if (proto is! firestore1.Value) {
      throw ArgumentError.value(
        proto,
        'proto',
        'Cannot decode type from Firestore Value: ${proto.runtimeType}',
      );
    }
    _assertValidProtobufValue(proto);

    if (proto.hasBooleanValue()) {
      return proto.booleanValue;
    } else if (proto.hasIntegerValue()) {
      return _createInteger(proto.integerValue);
    } else if (proto.hasDoubleValue()) {
      return proto.doubleValue;
    } else if (proto.hasReferenceValue()) {
      final resourcePath = _QualifiedResourcePath.fromSlashSeparatedString(
        proto.referenceValue,
      );
      return firestore.doc(resourcePath.relativeName);
    } else if (proto.hasMapValue()) {
      final fields = proto.mapValue.fields;
      return {
        for (final entry in fields.entries) entry.key: decodeValue(entry.value),
      };
    } else if (proto.hasGeoPointValue()) {
      return GeoPoint._fromProto(proto.geoPointValue);
    } else if (proto.hasArrayValue()) {
      final values = proto.arrayValue.values;
      return [
        for (final value in values) decodeValue(value),
      ];
    } else if (proto.hasTimestampValue()) {
      return Timestamp._fromProtoTimestamp(proto.timestampValue);
    } else if (proto.hasNullValue()) {
      return null;
    } else if (proto.hasStringValue()) {
      return proto.stringValue;
    } else if (proto.hasBytesValue()) {
      return proto.bytesValue;
    } else {
      throw ArgumentError.value(
        proto,
        'proto',
        'Cannot decode type from Firestore Value: ${proto.runtimeType}',
      );
    }
  }
}
