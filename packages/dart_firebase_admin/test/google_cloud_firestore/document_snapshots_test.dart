import 'package:dart_firebase_admin/firestore.dart';
import 'package:test/test.dart' hide throwsArgumentError;

import 'util/helpers.dart';

void main() {
  group('serialize document', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('serializes date before 1970', () async {
      await firestore.doc('collectionId/before1970').set({
        'moonLanding': DateTime(1960, 7, 20, 20, 18),
      });

      final data = await firestore
          .doc('collectionId/before1970')
          .snapshots()
          .first
          .then((snapshot) => snapshot.data()!['moonLanding']);

      expect(
        data,
        Timestamp.fromDate(DateTime(1960, 7, 20, 20, 18)),
      );
    });

    test('Supports BigInt', () async {
      final firestore =
          await createFirestore(settings: Settings(useBigInt: true));

      await firestore.doc('collectionId/bigInt').set({
        'foo': BigInt.from(9223372036854775807),
      });

      final data = await firestore
          .doc('collectionId/bigInt')
          .snapshots()
          .first
          .then((snapshot) => snapshot.data()!['foo']);

      expect(data, BigInt.from(9223372036854775807));
    });

    test('serializes unicode keys', () async {
      await firestore.doc('collectionId/unicode').set({
        '😀': '😜',
      });

      final data = await firestore
          .doc('collectionId/unicode')
          .snapshots()
          .first
          .then((snapshot) => snapshot.data());

      expect(data, {'😀': '😜'});
    });

    test('Supports NaN and Infinity', skip: true, () async {
      // This fails because GRPC uses dart:convert.json.encode which does not support NaN or Infinity
      await firestore.doc('collectionId/nan').set({
        'nan': double.nan,
        'infinity': double.infinity,
        'negativeInfinity': double.negativeInfinity,
      });

      final data = await firestore
          .doc('collectionId/nan')
          .snapshots()
          .first
          .then((snapshot) => snapshot.data());

      expect(data, {
        'nan': double.nan,
        'infinity': double.infinity,
        'negativeInfinity': double.negativeInfinity,
      });
    });
  });

  group('get document', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('returns document', () async {
      firestore = await createFirestore();
      await firestore.doc('collectionId/getdocument').set({
        'foo': {
          'bar': 'foobar',
        },
        'null': null,
      });

      final snapshot =
          await firestore.doc('collectionId/getdocument').snapshots().first;

      expect(snapshot.data(), {
        'foo': {'bar': 'foobar'},
        'null': null,
      });

      expect(snapshot.get('foo')?.value, {
        'bar': 'foobar',
      });
      expect(snapshot.get('unknown'), null);
      expect(snapshot.get('null'), isNotNull);
      expect(snapshot.get('null')!.value, null);
      expect(snapshot.get('foo.bar')?.value, 'foobar');

      expect(snapshot.get(FieldPath(const ['foo']))?.value, {
        'bar': 'foobar',
      });
      expect(snapshot.get(FieldPath(const ['foo', 'bar']))?.value, 'foobar');

      expect(snapshot.ref.id, 'getdocument');
    });

    test('returns update and create times', () async {
      final time = DateTime.now().toUtc().millisecondsSinceEpoch - 5000;

      await firestore.doc('collectionId/times').delete();
      await firestore.doc('collectionId/times').set({});

      final snapshot =
          await firestore.doc('collectionId/times').snapshots().first;

      expect(
        snapshot.createTime!.seconds * 1000,
        greaterThan(time),
      );
      expect(
        snapshot.updateTime!.seconds * 1000,
        greaterThan(time),
      );
      expect(
        snapshot.readTime,
        isNull, // Not supported for snapshots?
      );
    });

    test('returns not found', () async {
      await firestore.doc('collectionId/found').set({});

      final found = await firestore.doc('collectionId/found').snapshots().first;
      final notFound =
          await firestore.doc('collectionId/not_found').snapshots().first;

      expect(found.exists, isTrue);
      expect(found.data(), isNotNull);
      expect(found.createTime, isNotNull);
      expect(found.updateTime, isNotNull);
      expect(found.readTime, isNull); // Not supported for snapshots?

      expect(notFound.exists, isFalse);
      expect(notFound.data(), isNull);
      expect(notFound.createTime, isNull);
      expect(notFound.updateTime, isNull);
      expect(notFound.readTime, isNotNull);
    });
  });
}
