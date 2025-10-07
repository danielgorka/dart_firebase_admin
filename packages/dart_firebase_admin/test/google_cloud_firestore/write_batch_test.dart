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
  });
}
