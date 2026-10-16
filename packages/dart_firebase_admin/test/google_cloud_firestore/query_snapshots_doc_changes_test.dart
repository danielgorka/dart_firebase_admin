import 'dart:async';

import 'package:dart_firebase_admin/firestore.dart';
import 'package:test/test.dart';

import 'util/helpers.dart';

/// Collects snapshots from a stream and lets tests await the next one.
class _SnapshotQueue<T> {
  _SnapshotQueue(Stream<QuerySnapshot<T>> stream) {
    _subscription = stream.listen((snapshot) {
      final waiting = _waiters.isEmpty ? null : _waiters.removeAt(0);
      if (waiting != null) {
        waiting.complete(snapshot);
      } else {
        _buffer.add(snapshot);
      }
    });
    addTearDown(_subscription.cancel);
  }

  late final StreamSubscription<QuerySnapshot<T>> _subscription;
  final _buffer = <QuerySnapshot<T>>[];
  final _waiters = <Completer<QuerySnapshot<T>>>[];

  Future<QuerySnapshot<T>> next() {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final completer = Completer<QuerySnapshot<T>>();
    _waiters.add(completer);
    return completer.future.timeout(const Duration(seconds: 10));
  }
}

typedef _Change = (DocumentChangeType, String, int, int);

List<_Change> _summary(QuerySnapshot<Object?> snapshot) => [
      for (final change in snapshot.docChanges)
        (change.type, change.doc.id, change.oldIndex, change.newIndex),
    ];

void main() {
  group('QuerySnapshot.docChanges', () {
    late Firestore firestore;

    setUp(() async => firestore = await createFirestore());

    test('first snapshot reports every document as added', () async {
      final collection = firestore.collection('docChangesInitial');
      await collection.doc('a').set({'v': 1});
      await collection.doc('b').set({'v': 2});

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      final snapshot = await queue.next();

      expect(_summary(snapshot), [
        (DocumentChangeType.added, 'a', -1, 0),
        (DocumentChangeType.added, 'b', -1, 1),
      ]);
    });

    test('first snapshot of empty collection has no changes', () async {
      final queue = _SnapshotQueue(
        firestore.collection('docChangesEmpty').snapshots(),
      );
      final snapshot = await queue.next();

      expect(snapshot.docs, isEmpty);
      expect(snapshot.docChanges, isEmpty);
    });

    test('adding a document only reports that document', () async {
      final collection = firestore.collection('docChangesAdd');
      await collection.doc('a').set({'v': 1});
      await collection.doc('c').set({'v': 3});

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      await queue.next();

      await collection.doc('b').set({'v': 2});
      final snapshot = await queue.next();

      expect(snapshot.docs.map((d) => d.id), ['a', 'b', 'c']);
      expect(_summary(snapshot), [
        (DocumentChangeType.added, 'b', -1, 1),
      ]);
    });

    test('removing a document only reports that document', () async {
      final collection = firestore.collection('docChangesRemove');
      await collection.doc('a').set({'v': 1});
      await collection.doc('b').set({'v': 2});
      await collection.doc('c').set({'v': 3});

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      await queue.next();

      await collection.doc('b').delete();
      final snapshot = await queue.next();

      expect(snapshot.docs.map((d) => d.id), ['a', 'c']);
      expect(_summary(snapshot), [
        (DocumentChangeType.removed, 'b', 1, -1),
      ]);
    });

    test('editing a document only reports that document as modified', () async {
      final collection = firestore.collection('docChangesModify');
      await collection.doc('a').set({'v': 1});
      await collection.doc('b').set({'v': 2});
      await collection.doc('c').set({'v': 3});

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      await queue.next();

      await collection.doc('b').update({'extra': 'x'});
      final snapshot = await queue.next();

      expect(snapshot.docs, hasLength(3));
      expect(_summary(snapshot), [
        (DocumentChangeType.modified, 'b', 1, 1),
      ]);
      expect(snapshot.docChanges.single.doc.data()['extra'], 'x');
    });

    test('modification that changes ordering reports old and new index',
        () async {
      final collection = firestore.collection('docChangesReorder');
      await collection.doc('a').set({'v': 1});
      await collection.doc('b').set({'v': 2});
      await collection.doc('c').set({'v': 3});

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      await queue.next();

      await collection.doc('a').update({'v': 10});
      final snapshot = await queue.next();

      expect(snapshot.docs.map((d) => d.id), ['b', 'c', 'a']);
      expect(_summary(snapshot), [
        (DocumentChangeType.modified, 'a', 0, 2),
      ]);
    });

    test('multiple changes in one batch are all reported', () async {
      final collection = firestore.collection('docChangesBatch');
      await collection.doc('a').set({'v': 1});
      await collection.doc('b').set({'v': 2});
      await collection.doc('c').set({'v': 3});

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      await queue.next();

      final batch = firestore.batch()
        ..delete(collection.doc('a'))
        ..update(collection.doc('b'), {
          FieldPath(const ['extra']): 1
        })
        ..set(collection.doc('d'), {'v': 4});
      await batch.commit();

      final snapshot = await queue.next();

      expect(snapshot.docs.map((d) => d.id), ['b', 'c', 'd']);
      expect(
        _summary(snapshot),
        unorderedEquals([
          (DocumentChangeType.removed, 'a', 0, -1),
          (DocumentChangeType.modified, 'b', 0, 0),
          (DocumentChangeType.added, 'd', -1, 2),
        ]),
      );
      // Unchanged document must not be reported.
      expect(snapshot.docChanges.map((c) => c.doc.id), isNot(contains('c')));
    });

    test('docChanges applied to the previous docs give the new docs', () async {
      final collection = firestore.collection('docChangesReplay');
      String id(int i) => 'd${'$i'.padLeft(3, '0')}';
      final setup = firestore.batch();
      for (var i = 0; i < 200; i++) {
        setup.set(collection.doc(id(i)), {'v': i});
      }
      await setup.commit();

      final queue = _SnapshotQueue(collection.orderBy('v').snapshots());
      final first = await queue.next();
      final docs = first.docs.map((d) => d.id).toList();

      // Removals, moves in both directions, edits in place and additions
      // spread over the whole result set.
      final batch = firestore.batch();
      for (var i = 0; i < 200; i++) {
        final doc = collection.doc(id(i));
        if (i % 7 == 0) {
          batch.delete(doc);
        } else if (i % 11 == 3) {
          batch.update(doc, {
            FieldPath(const ['v']): 199 - i + 0.5
          });
        } else if (i % 13 == 5) {
          batch.update(doc, {
            FieldPath(const ['extra']): true
          });
        }
      }
      for (var i = 0; i < 20; i++) {
        batch.set(collection.doc('n$i'), {'v': i * 10 + 0.25});
      }
      await batch.commit();
      final snapshot = await queue.next();

      for (final change in snapshot.docChanges) {
        if (change.oldIndex != -1) {
          expect(docs.removeAt(change.oldIndex), change.doc.id);
        }
        if (change.newIndex != -1) docs.insert(change.newIndex, change.doc.id);
      }
      expect(docs, snapshot.docs.map((d) => d.id));
      expect(
        snapshot.docs.map((d) => d.id),
        (await collection.orderBy('v').get()).docs.map((d) => d.id),
      );
    });

    group('with where() filter', () {
      test('document entering the filter is reported as added', () async {
        final collection = firestore.collection('docChangesWhereEnter');
        await collection.doc('a').set({'on': true, 'v': 1});
        await collection.doc('b').set({'on': false, 'v': 2});

        final queue = _SnapshotQueue(
          collection.where('on', WhereFilter.equal, true).snapshots(),
        );
        final first = await queue.next();
        expect(_summary(first), [
          (DocumentChangeType.added, 'a', -1, 0),
        ]);

        await collection.doc('b').update({'on': true});
        final snapshot = await queue.next();

        expect(snapshot.docs.map((d) => d.id), ['a', 'b']);
        expect(_summary(snapshot), [
          (DocumentChangeType.added, 'b', -1, 1),
        ]);
      });

      test('document leaving the filter is reported as removed', () async {
        final collection = firestore.collection('docChangesWhereLeave');
        await collection.doc('a').set({'on': true});
        await collection.doc('b').set({'on': true});

        final queue = _SnapshotQueue(
          collection.where('on', WhereFilter.equal, true).snapshots(),
        );
        await queue.next();

        await collection.doc('a').update({'on': false});
        final snapshot = await queue.next();

        expect(snapshot.docs.map((d) => d.id), ['b']);
        expect(_summary(snapshot), [
          (DocumentChangeType.removed, 'a', 0, -1),
        ]);
      });

      test('changes to documents outside the filter are not emitted', () async {
        final collection = firestore.collection('docChangesWhereIgnore');
        await collection.doc('a').set({'on': true});
        await collection.doc('b').set({'on': false});

        final queue = _SnapshotQueue(
          collection.where('on', WhereFilter.equal, true).snapshots(),
        );
        await queue.next();

        // Neither of these affects the filtered result set.
        await collection.doc('b').update({'other': 1});
        await collection.doc('c').set({'on': false});
        // This one does, and must be the very next snapshot.
        await collection.doc('d').set({'on': true});

        final snapshot = await queue.next();
        expect(_summary(snapshot), [
          (DocumentChangeType.added, 'd', -1, 1),
        ]);
      });

      test('modifying a matching document is reported as modified', () async {
        final collection = firestore.collection('docChangesWhereModify');
        await collection.doc('a').set({'on': true, 'n': 1});
        await collection.doc('b').set({'on': true, 'n': 1});

        final queue = _SnapshotQueue(
          collection.where('on', WhereFilter.equal, true).snapshots(),
        );
        await queue.next();

        await collection.doc('b').update({'n': 2});
        final snapshot = await queue.next();

        expect(_summary(snapshot), [
          (DocumentChangeType.modified, 'b', 1, 1),
        ]);
      });

      test('deleting a matching document is reported as removed', () async {
        final collection = firestore.collection('docChangesWhereDelete');
        await collection.doc('a').set({'on': true});

        final queue = _SnapshotQueue(
          collection.where('on', WhereFilter.equal, true).snapshots(),
        );
        await queue.next();

        await collection.doc('a').delete();
        final snapshot = await queue.next();

        expect(snapshot.docs, isEmpty);
        expect(_summary(snapshot), [
          (DocumentChangeType.removed, 'a', 0, -1),
        ]);
      });
    });
  });
}
