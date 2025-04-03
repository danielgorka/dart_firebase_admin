part of 'firestore.dart';

/// Verifies that a `Value` only has a single type set.
void _assertValidProtobufValue(firestore1.Value proto) {
  final values = [
    proto.hasBooleanValue(),
    proto.hasDoubleValue(),
    proto.hasIntegerValue(),
    proto.hasStringValue(),
    proto.hasTimestampValue(),
    proto.hasNullValue(),
    proto.hasMapValue(),
    proto.hasArrayValue(),
    proto.hasReferenceValue(),
    proto.hasGeoPointValue(),
    proto.hasBytesValue(),
  ];

  if (values.where((b) => b).length != 1) {
    throw ArgumentError.value(
      proto,
      'proto',
      'Unable to infer type value',
    );
  }
}
