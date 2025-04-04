import 'package:dart_firebase_admin/firestore.dart';
import 'package:test/test.dart';

import 'util/helpers.dart';

void main() {
  group('query interface', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('accepts all variations', () async {
      final query = firestore
          .collection('allVarations')
          .where('foo', WhereFilter.equal, '1')
          .orderBy('foo')
          .limit(10);

      final snapshot = await query.snapshots().first;

      expect(snapshot.docs, isEmpty);
      expect(snapshot.query, query);
    });

    test('Supports empty snapshot', () async {
      final snapshot = await firestore.collection('emptyget').snapshots().first;

      expect(snapshot.docs, isEmpty);
      expect(snapshot.readTime, isNotNull);
    });

    // TODO handle retries

    test('propagates withConverter() through QueryOptions', () async {
      final collection =
          firestore.collection('withConverterQueryOptions').withConverter<int>(
                fromFirestore: (snapshot) => snapshot.data()['value']! as int,
                toFirestore: (value) => {'value': value},
              );

      await collection.doc('doc').set(42);
      await collection.doc('doc2').set(1);

      final query = collection.where('value', WhereFilter.equal, 1);
      expect(query, isA<Query<int>>());

      final snapshot = await query.snapshots().first;

      expect(snapshot.docs.single.ref, collection.doc('doc2'));
      expect(snapshot.docs.single.data(), 1);
    });

    test('supports OR queries with cursors', () async {
      final collection = firestore.collection('orQueryWithCursors');
      final query = collection
          .orderBy('a')
          .whereFilter(
            Filter.or([
              Filter.where('a', WhereFilter.greaterThanOrEqual, 4),
              Filter.where('a', WhereFilter.equal, 2),
              // Unused due to startAt
              Filter.where('a', WhereFilter.equal, 0),
            ]),
          )
          .startAt([1]).limit(3);

      await Future.wait([
        collection.doc('0').set({'a': 0}),
        collection.doc('1').set({'a': 1}),
        collection.doc('2').set({'a': 2}),
        collection.doc('3').set({'a': 3}),
        collection.doc('4').set({'a': 4}),
        collection.doc('5').set({'a': 5}),
        collection.doc('6').set({'a': 6}),
      ]);

      final snapshot = await query.snapshots().first;

      expect(snapshot.docs.map((doc) => doc.id), ['2', '4', '5']);
    });
  });

  group('where()', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('accepts objects', () async {
      final collection = firestore.collection('whereObjects');
      final doc = collection.doc('doc');

      await doc.set({
        'a': {'b': 1},
      });

      final snapshot = await collection
          .where(
            'a',
            WhereFilter.equal,
            {'b': 1},
          )
          .snapshots()
          .first;

      expect(snapshot.docs.single.ref, doc);
    });

    test('supports field path objects', () async {
      final collection = firestore.collection('whereFieldPathObj');
      final doc = collection.doc('doc');

      await doc.set({
        'a': {'b': 1},
      });

      final snapshot = await collection
          .where(FieldPath(const ['a', 'b']), WhereFilter.equal, 1)
          .snapshots()
          .first;

      expect(snapshot.docs.single.ref, doc);
    });

    test('supports reference array for IN queries', () async {
      final collection = firestore.collection('whereReferenceArray');

      final doc2 = collection.doc('doc');
      await doc2.set({});
      await collection.doc('doc2').set({});

      final snapshot = await collection
          .where(
            FieldPath.documentId,
            WhereFilter.isIn,
            [doc2],
          )
          .snapshots()
          .first;

      expect(snapshot.docs.single.ref, doc2);
    });

    test('Fields of IN queries are not used in implicit order by', () async {
      final collection = firestore.collection('whereInImplicitOrderBy');

      await collection.doc('b').set({'foo': 'bar'});
      await collection.doc('a').set({'foo': 'bar'});

      final snapshot = await collection
          .where('foo', WhereFilter.isIn, ['bar'])
          .snapshots()
          .first;

      expect(snapshot.docs.map((doc) => doc.id), ['a', 'b']);
    });

    test('supports isNull', () async {
      final collection = firestore.collection('whereNull');

      final doc = collection.doc('doc');
      await doc.set({'a': null});
      await collection.doc('doc2').set({'a': 42});

      final snapshot = await collection
          .where(
            'a',
            WhereFilter.equal,
            null,
          )
          .snapshots()
          .first;

      expect(snapshot.docs.single.ref, doc);
    });

    test('supports isNotNull', () async {
      final collection = firestore.collection('whereNull');

      final doc = collection.doc('doc');
      await doc.set({'a': 42});
      await collection.doc('doc2').set({'a': null});

      final snapshot = await collection
          .where(
            'a',
            WhereFilter.notEqual,
            null,
          )
          .snapshots()
          .first;

      expect(snapshot.docs.single.ref, doc);
    });
  });

  group('orderBy', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('accepts asc', () async {
      final collection = firestore.collection('orderByAsc');

      await collection.doc('a').set({'foo': 1});
      await collection.doc('b').set({'foo': 2});

      final snapshot = await collection.orderBy('foo').snapshots().first;
      expect(snapshot.docs.map((doc) => doc.id), ['a', 'b']);

      final snapshot2 =
          await collection.orderBy('foo', descending: true).snapshots().first;
      expect(snapshot2.docs.map((doc) => doc.id), ['b', 'a']);
    });

    test('concatenantes orders', () async {
      final collection = firestore.collection('orderByConcat');

      await collection.doc('d').set({'foo': 1, 'bar': 1});
      await collection.doc('c').set({'foo': 1, 'bar': 2});
      await collection.doc('b').set({'foo': 2, 'bar': 1});
      await collection.doc('a').set({'foo': 2, 'bar': 2});

      final snapshot =
          await collection.orderBy('foo').orderBy('bar').snapshots().first;
      expect(snapshot.docs.map((doc) => doc.id), ['d', 'c', 'b', 'a']);
    });
  });

  group('limit()', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('uses latest limit', () async {
      final collection = firestore.collection('limitLatest');

      await collection.doc('a').set({'foo': 1});
      await collection.doc('b').set({'foo': 2});
      await collection.doc('c').set({'foo': 3});

      final snapshot = await collection.limit(1).limit(2).snapshots().first;
      expect(snapshot.docs.map((doc) => doc.id), ['a', 'b']);
    });
  });

  group('limitToLast()', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('uses latest limit', () async {
      final collection = firestore.collection('limitLast');

      await collection.doc('a').set({'foo': 1});
      await collection.doc('b').set({'foo': 2});
      await collection.doc('c').set({'foo': 3});

      final snapshot = await collection
          .orderBy('foo')
          .limitToLast(1)
          .limitToLast(2)
          .snapshots()
          .first;
      expect(snapshot.docs.map((doc) => doc.id), ['c', 'b']);
    });
  });
}
