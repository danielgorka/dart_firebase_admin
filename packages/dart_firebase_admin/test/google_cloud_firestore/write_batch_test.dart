// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_firebase_admin/firestore.dart';
import 'package:test/test.dart';
import 'util/helpers.dart' as helpers;

void main() {
  group('WriteBatch', () {
    late Firestore firestore;

    setUp(() async => firestore = await helpers.createFirestore());

    Future<DocumentReference<Map<String, dynamic>>> initializeTest(
      String path,
    ) async {
      final String prefixedPath = 'flutter-tests/$path';
      await firestore.doc(prefixedPath).delete();
      addTearDown(() => firestore.doc(prefixedPath).delete());

      return firestore.doc(prefixedPath);
    }

    test('commit creates a document', () async {
      final docRef = await initializeTest('batch-create-doc');
      final batch = firestore.batch();

      batch.create(docRef, {'value': 42});
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data()!['value'], 42);
    });

    test('commit sets a document', () async {
      final docRef = await initializeTest('batch-set-doc');
      final batch = firestore.batch();

      batch.set(docRef, {'value': 100, 'name': 'test'});
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data()!['value'], 100);
      expect(snapshot.data()!['name'], 'test');
    });

    test('commit updates a document', () async {
      final docRef = await initializeTest('batch-update-doc');
      await docRef.set({'value': 1, 'name': 'original'});

      final batch = firestore.batch();
      batch.update(docRef, {
        FieldPath(const ['value']): 2,
      });
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.data()!['value'], 2);
      expect(snapshot.data()!['name'], 'original');
    });

    test('commit deletes a document', () async {
      final docRef = await initializeTest('batch-delete-doc');
      await docRef.set({'value': 1});

      final batch = firestore.batch();
      batch.delete(docRef);
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.exists, false);
    });

    test('commit performs multiple operations', () async {
      final doc1 = await initializeTest('batch-multi-1');
      final doc2 = await initializeTest('batch-multi-2');
      final doc3 = await initializeTest('batch-multi-3');

      await doc2.set({'value': 10});

      final batch = firestore.batch();
      batch.create(doc1, {'value': 1});
      batch.update(doc2, {
        FieldPath(const ['value']): 20,
      });
      batch.set(doc3, {'value': 30});
      await batch.commit();

      final snapshot1 = await doc1.get();
      final snapshot2 = await doc2.get();
      final snapshot3 = await doc3.get();

      expect(snapshot1.data()!['value'], 1);
      expect(snapshot2.data()!['value'], 20);
      expect(snapshot3.data()!['value'], 30);
    });

    test('cannot modify batch after commit', () async {
      final docRef = await initializeTest('batch-committed');
      final batch = firestore.batch();

      batch.set(docRef, {'value': 1});
      await batch.commit();

      expect(
        () => batch.set(docRef, {'value': 2}),
        throwsA(isA<StateError>()),
      );
    });

    test('reset allows reusing batch', () async {
      final doc1 = await initializeTest('batch-reset-1');
      final doc2 = await initializeTest('batch-reset-2');
      final batch = firestore.batch();

      batch.set(doc1, {'value': 1});
      await batch.commit();

      batch.reset();

      batch.set(doc2, {'value': 2});
      await batch.commit();

      final snapshot1 = await doc1.get();
      final snapshot2 = await doc2.get();

      expect(snapshot1.data()!['value'], 1);
      expect(snapshot2.data()!['value'], 2);
    });

    test('commit returns WriteResults', () async {
      final docRef = await initializeTest('batch-write-results');
      final batch = firestore.batch();

      batch.set(docRef, {'value': 1});
      final results = await batch.commit();

      expect(results, isNotEmpty);
      expect(results.length, 1);
      expect(results[0], isA<WriteResult>());
      expect(results[0].writeTime, isA<Timestamp>());
    });

    test('commit with multiple operations returns multiple WriteResults',
        () async {
      final doc1 = await initializeTest('batch-results-1');
      final doc2 = await initializeTest('batch-results-2');
      final doc3 = await initializeTest('batch-results-3');

      final batch = firestore.batch();
      batch.set(doc1, {'value': 1});
      batch.set(doc2, {'value': 2});
      batch.set(doc3, {'value': 3});
      final results = await batch.commit();

      expect(results.length, 3);
      for (final result in results) {
        expect(result, isA<WriteResult>());
        expect(result.writeTime, isA<Timestamp>());
      }
    });

    // Note: Testing retry behavior with transient errors is difficult without
    // mocking the gRPC client. The retry logic handles these error codes:
    // - UNKNOWN (connection errors)
    // - UNAVAILABLE
    // - INTERNAL
    // - DEADLINE_EXCEEDED
    // - ABORTED
    // - CANCELLED
    // - UNAUTHENTICATED
    // - RESOURCE_EXHAUSTED
    //
    // The retry mechanism:
    // 1. Retries up to 5 times (_maxCommitAttempts)
    // 2. Uses exponential backoff (1s, 1.5s, 2.25s, ...)
    // 3. Max backoff delay is 60 seconds
    // 4. Only retries on transient errors
    // 5. Rethrows permanent errors immediately (e.g., PERMISSION_DENIED)

    test('commit fails on non-retryable errors immediately', () async {
      final docRef = await initializeTest('batch-non-retryable');
      await docRef.set({'value': 1});

      final batch = firestore.batch();
      // Create will fail if document already exists - this is ALREADY_EXISTS error
      batch.create(docRef, {'value': 2});

      expect(
        batch.commit,
        throwsA(
          isA<FirebaseFirestoreAdminException>().having(
            (e) => e.errorCode,
            'errorCode',
            FirestoreClientErrorCode.alreadyExists,
          ),
        ),
      );
    });

    test('commit sets a document with merge=true', () async {
      final docRef = await initializeTest('batch-set-merge');

      // Create initial document
      await docRef.set({'field1': 'value1', 'field2': 'value2'});

      final batch = firestore.batch();
      batch.set(docRef, {'field2': 'updated', 'field3': 'new'}, merge: true);
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.data(), {
        'field1': 'value1',
        'field2': 'updated',
        'field3': 'new',
      });
    });

    test('commit sets a document with merge=false replaces document', () async {
      final docRef = await initializeTest('batch-set-no-merge');

      // Create initial document
      await docRef.set({'field1': 'value1', 'field2': 'value2'});

      final batch = firestore.batch();
      batch.set(docRef, {'field3': 'new'});
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.data(), {'field3': 'new'});
    });

    test('commit sets with default merge=false', () async {
      final docRef = await initializeTest('batch-set-default');

      // Create initial document
      await docRef.set({'field1': 'value1', 'field2': 'value2'});

      final batch = firestore.batch();
      batch.set(docRef, {'field3': 'new'});
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.data(), {'field3': 'new'});
    });

    test('commit creates document with merge=true if not exists', () async {
      final docRef = await initializeTest('batch-merge-create');

      final batch = firestore.batch();
      batch.set(docRef, {'field1': 'value1'}, merge: true);
      await batch.commit();

      final snapshot = await docRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data(), {'field1': 'value1'});
    });

    test('commit multiple operations with merge', () async {
      final doc1 = await initializeTest('batch-multi-merge-1');
      final doc2 = await initializeTest('batch-multi-merge-2');
      final doc3 = await initializeTest('batch-multi-merge-3');

      await doc1.set({'existing': 'field'});
      await doc2.set({'existing': 'field'});

      final batch = firestore.batch();
      batch.set(doc1, {'new': 'field'}, merge: true);
      batch.set(doc2, {'replaced': 'field'});
      batch.set(doc3, {'created': 'field'}, merge: true);
      await batch.commit();

      final snapshot1 = await doc1.get();
      final snapshot2 = await doc2.get();
      final snapshot3 = await doc3.get();

      expect(snapshot1.data(), {'existing': 'field', 'new': 'field'});
      expect(snapshot2.data(), {'replaced': 'field'});
      expect(snapshot3.data(), {'created': 'field'});
    });

    test('commit with merge and withConverter', () async {
      final rawDocRef = await initializeTest('batch-merge-converter');

      final docRef = rawDocRef.withConverter<int>(
        fromFirestore: (snapshot) => snapshot.data()['value']! as int,
        toFirestore: (value) => {'value': value},
      );

      // Create initial document with extra field
      await rawDocRef.set({'value': 10, 'extra': 'field'});

      final batch = firestore.batch();
      batch.set(docRef, 20, merge: true);
      await batch.commit();

      final snapshot = await rawDocRef.get();
      expect(snapshot.data(), {'value': 20, 'extra': 'field'});

      final converterSnapshot = await docRef.get();
      expect(converterSnapshot.data(), 20);
    });

    test('commit with merge preserves fields with transforms', () async {
      final docRef = await initializeTest('batch-merge-transform');

      await docRef.set({'existing': 'field'});

      final batch = firestore.batch();
      batch.set(
        docRef,
        {
          'timestamp': FieldValue.serverTimestamp,
        },
        merge: true,
      );
      await batch.commit();

      final snapshot = await docRef.get();
      final data = snapshot.data()!;

      expect(data['existing'], 'field');
      expect(data['timestamp'], isA<Timestamp>());
    });

    test('commit with mixed operations including merge', () async {
      final doc1 = await initializeTest('batch-mixed-1');
      final doc2 = await initializeTest('batch-mixed-2');
      final doc3 = await initializeTest('batch-mixed-3');
      final doc4 = await initializeTest('batch-mixed-4');

      await doc2.set({'old': 'value'});
      await doc3.set({'update': 'me', 'keep': 'this'});
      await doc4.set({'delete': 'me'});

      final batch = firestore.batch();
      batch.create(doc1, {'created': 'value'});
      batch.set(doc2, {'merged': 'value'}, merge: true);
      batch.update(doc3, {
        FieldPath(const ['update']): 'updated',
      });
      batch.delete(doc4);
      await batch.commit();

      final snapshot1 = await doc1.get();
      final snapshot2 = await doc2.get();
      final snapshot3 = await doc3.get();
      final snapshot4 = await doc4.get();

      expect(snapshot1.data(), {'created': 'value'});
      expect(snapshot2.data(), {'old': 'value', 'merged': 'value'});
      expect(snapshot3.data(), {'update': 'updated', 'keep': 'this'});
      expect(snapshot4.exists, false);
    });

    group('set with merge', () {
      test('merges nested maps instead of replacing them', () async {
        final docRef = await initializeTest('batch-merge-nested');
        await docRef.set({
          'notifications': {
            'n1': {'read': true, 'title': 'first'},
            'n2': {'read': false, 'title': 'second'},
          },
          'other': 'field',
        });

        final batch = firestore.batch();
        batch.set(
          docRef,
          {
            'notifications': {
              'n2': {'read': true},
              'n3': {'read': false, 'title': 'third'},
            },
          },
          merge: true,
        );
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'notifications': {
            'n1': {'read': true, 'title': 'first'},
            'n2': {'read': true, 'title': 'second'},
            'n3': {'read': false, 'title': 'third'},
          },
          'other': 'field',
        });
      });

      test('creates a missing document with nested data', () async {
        final docRef = await initializeTest('batch-merge-nested-create');

        final batch = firestore.batch();
        batch.set(
          docRef,
          {
            'notifications': {
              'n1': {'read': false},
            },
          },
          merge: true,
        );
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'notifications': {
            'n1': {'read': false},
          },
        });
      });

      test("doesn't split top-level keys on dots", () async {
        final docRef = await initializeTest('batch-merge-dots');
        await docRef.set({
          'a': {'b': 'nested'},
        });

        final batch = firestore.batch();
        batch.set(docRef, {'a.b': 'literal'}, merge: true);
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'a': {'b': 'nested'},
          'a.b': 'literal',
        });
      });

      test("doesn't split nested keys on dots", () async {
        final docRef = await initializeTest('batch-merge-nested-dots');
        await docRef.set({
          'notifications': {
            'user@example.com': {'read': false},
            'keep': 'me',
          },
        });

        final batch = firestore.batch();
        batch.set(
          docRef,
          {
            'notifications': {
              'user@example.com': {'read': true},
              'other.user@example.com': {'read': false},
            },
          },
          merge: true,
        );
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'notifications': {
            'user@example.com': {'read': true},
            'other.user@example.com': {'read': false},
            'keep': 'me',
          },
        });
      });

      test('supports keys that require escaping', () async {
        final docRef = await initializeTest('batch-merge-escaping');
        await docRef.set({'keep': 'me'});

        final batch = firestore.batch();
        batch.set(
          docRef,
          {
            'a`b': 1,
            r'c\d': 2,
            'map': {'e`f.g': 3},
          },
          merge: true,
        );
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'keep': 'me',
          'a`b': 1,
          r'c\d': 2,
          'map': {'e`f.g': 3},
        });
      });

      test('replaces a field with an explicitly set empty map', () async {
        final docRef = await initializeTest('batch-merge-empty-map');
        await docRef.set({
          'a': {'b': 'c'},
          'keep': 'me',
        });

        final batch = firestore.batch();
        batch.set(docRef, {'a': <String, Object?>{}}, merge: true);
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'a': <String, Object?>{},
          'keep': 'me',
        });
      });

      test('applies nested field transforms without replacing siblings',
          () async {
        final docRef = await initializeTest('batch-merge-transforms');
        await docRef.set({
          'stats': {'count': 1, 'keep': 'me'},
        });

        final batch = firestore.batch();
        batch.set(
          docRef,
          {
            'stats': {
              'count': const FieldValue.increment(2),
              'updated.at': FieldValue.serverTimestamp,
            },
          },
          merge: true,
        );
        await batch.commit();

        final data = (await docRef.get()).data()!;
        final stats = data['stats']! as Map<String, Object?>;
        expect(stats['count'], 3);
        expect(stats['keep'], 'me');
        expect(stats['updated.at'], isA<Timestamp>());
        expect(stats.keys, unorderedEquals(['count', 'keep', 'updated.at']));
      });

      test('supports nested FieldValue.delete', () async {
        final docRef = await initializeTest('batch-merge-delete');
        await docRef.set({
          'notifications': {
            'n1': {'read': true},
            'n2': {'read': false},
          },
          'removed': 'value',
        });

        final batch = firestore.batch();
        batch.set(
          docRef,
          {
            'notifications': {'n1': FieldValue.delete},
            'removed': FieldValue.delete,
          },
          merge: true,
        );
        await batch.commit();

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'notifications': {
            'n2': {'read': false},
          },
        });
      });

      test('DocumentReference.set uses the same nested merge', () async {
        final docRef = await initializeTest('ref-merge-nested');
        await docRef.set({
          'notifications': {
            'n1': {'read': false},
          },
        });

        await docRef.set(
          {
            'notifications': {
              'n2': {'read': false},
            },
          },
          merge: true,
        );

        final snapshot = await docRef.get();
        expect(snapshot.data(), {
          'notifications': {
            'n1': {'read': false},
            'n2': {'read': false},
          },
        });
      });
    });
  });
}
