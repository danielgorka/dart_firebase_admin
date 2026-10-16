part of 'firestore.dart';

class _QueryWatcher<T> {
  _QueryWatcher({
    required this.firestore,
    required this.query,
    this.readTime,
    void Function()? onDone,
  }) {
    final documentsTarget = firestore1.Target(
      query: query._toProtoTarget(),
      readTime: readTime?._toProto().timestampValue,
    );

    final request = firestore1.ListenRequest(
      database: firestore._formattedDatabaseName,
      addTarget: documentsTarget,
    );

    _streamWrapper = _ListenStreamWrapper.create(
      request,
      (requestStream) => firestore._client.v1Stream(
        (client) => client.listen(
          requestStream,
          options: grpc.CallOptions(
            metadata: {
              'google-cloud-resource-prefix': firestore._formattedDatabaseName,
            },
          ),
        ),
      ),
      onDone: () => onDone?.call(),
    );
  }

  final Firestore firestore;
  final Query<T> query;
  final Timestamp? readTime;

  late _ListenStreamWrapper _streamWrapper;

  Stream<QuerySnapshot<T>> get stream =>
      _mapQuerySnapshotStream(_streamWrapper);

  /// Maps the response stream to a stream of QuerySnapshot.
  ///
  /// On connect the following responses are emitted:
  /// 1. Type.ADD
  /// 2. documentChange... (for each document)
  /// 3. Type.CURRENT
  /// 4. targetChange (no type)
  /// 5. filter (count, bits)
  /// 6. targetChange... (no type) (ping every 45 seconds)
  ///
  /// If the document is modified so it no longer satisfies the query,
  /// the response with documentChange with removedTargetIds is emitted.
  ///
  /// After every change, the stream emits a new targetChange without
  /// type but with resumeToken. We use it as 'commit' message to emit the
  /// snapshot.
  Stream<QuerySnapshot<T>> _mapQuerySnapshotStream(
    _ListenStreamWrapper wrapper,
  ) {
    // Emitted documents in query order, each with its converted snapshot.
    final current = <_EmittedDoc<T>>[];
    // Emitted documents by name (the documentMap key).
    final emitted = <String, DocumentSnapshot<DocumentData>>{};
    // Names of documents touched since the last emitted snapshot.
    final changedNames = <String>{};
    var hasEmitted = false;

    return wrapper.stream.map(
      (response) {
        if (response.hasTargetChange() && response.targetChange.hasCause()) {
          // Handle error
          throw FirebaseFirestoreAdminException.fromServerError(
            serverErrorCode: Code.values[response.targetChange.cause.code].name,
            message: response.targetChange.cause.message,
          );
        }

        if (response.hasTargetChange() &&
            response.targetChange.targetChangeType ==
                firestore1.TargetChange_TargetChangeType.RESET) {
          // The backend will resend the full result set; documents it does
          // not resend are removed.
          changedNames.addAll(wrapper.documentMap.keys);
          wrapper.documentMap.clear();
        }

        if (response.hasDocumentChange()) {
          final name = response.documentChange.document.name;
          changedNames.add(name);
          if (response.documentChange.removedTargetIds.isEmpty) {
            wrapper.documentMap[name] = DocumentSnapshot._fromDocument(
              response.documentChange.document,
              null,
              firestore,
            );
          } else {
            wrapper.documentMap.remove(name);
          }
        }

        if (response.hasDocumentDelete()) {
          changedNames.add(response.documentDelete.document);
          wrapper.documentMap.remove(response.documentDelete.document);
        }

        if (response.hasDocumentRemove()) {
          changedNames.add(response.documentRemove.document);
          wrapper.documentMap.remove(response.documentRemove.document);
        }

        // A target change without type commits the received changes.
        if (!response.hasTargetChange() ||
            response.targetChange.hasTargetChangeType()) {
          // Don't emit anything until all documents are received
          return null;
        }

        wrapper.readTime =
            Timestamp._fromProtoTimestamp(response.targetChange.readTime);
        final changes = _applyChanges(
          current,
          emitted,
          changedNames,
          wrapper.documentMap,
        );
        changedNames.clear();

        // Like the official SDKs, only emit the first snapshot and then
        // snapshots that actually contain changes.
        if (hasEmitted && changes.isEmpty) return null;
        hasEmitted = true;

        return QuerySnapshot._(
          query: query,
          readTime: wrapper.readTime,
          docs: [for (final doc in current) doc.converted],
          docChanges: changes,
        );
      },
    ).whereNotNull();
  }

  late final List<_FieldOrder> _orderBy = query._createBackendOrderBy();

  int _compareDocs(
    DocumentSnapshot<DocumentData> a,
    DocumentSnapshot<DocumentData> b,
  ) {
    for (final order in _orderBy) {
      final comparison = order._compare(a, b);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  /// Index of [doc] in [docs], or where to insert it. The order always ends
  /// with the document name, so it is total.
  int _lowerBound(
    List<_EmittedDoc<T>> docs,
    DocumentSnapshot<DocumentData> doc,
  ) {
    var min = 0;
    var max = docs.length;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      if (_compareDocs(docs[mid].raw, doc) < 0) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return min;
  }

  /// Recreates [snapshot] with a reference containing the original converter.
  QueryDocumentSnapshot<T> _convert(DocumentSnapshot<DocumentData> snapshot) {
    final finalDoc = _DocumentSnapshotBuilder(
      snapshot.ref.withConverter<T>(
        fromFirestore: query._queryOptions.converter.fromFirestore,
        toFirestore: query._queryOptions.converter.toFirestore,
      ),
    )
      ..fieldsProto = snapshot._fieldsProto
      ..createTime = snapshot.createTime
      ..readTime = snapshot.readTime
      ..updateTime = snapshot.updateTime;

    return finalDoc.build() as QueryDocumentSnapshot<T>;
  }

  /// Applies the documents touched since the last snapshot ([changedNames])
  /// to [current] and returns the changes, the same way the official SDKs
  /// do: removals first (using old indexes), then additions and
  /// modifications (using indexes in the progressively updated set).
  ///
  /// Only touched documents are compared, so a snapshot costs
  /// O(changes * log n) comparisons instead of diffing the whole result set.
  List<DocumentChange<T>> _applyChanges(
    List<_EmittedDoc<T>> current,
    Map<String, DocumentSnapshot<DocumentData>> emitted,
    Set<String> changedNames,
    Map<String, DocumentSnapshot<DocumentData>> documentMap,
  ) {
    final removed = <(String, DocumentSnapshot<DocumentData>)>[];
    final upserted = <(String, DocumentSnapshot<DocumentData>)>[];
    for (final name in changedNames) {
      final old = emitted[name];
      final doc = documentMap[name];
      if (doc == null) {
        if (old != null) removed.add((name, old));
      } else if (old == null || old.updateTime != doc.updateTime) {
        upserted.add((name, doc));
      }
    }
    removed.sort((a, b) => _compareDocs(a.$2, b.$2));
    upserted.sort((a, b) => _compareDocs(a.$2, b.$2));

    final changes = <DocumentChange<T>>[];
    for (final (name, old) in removed) {
      final oldIndex = _lowerBound(current, old);
      final removedDoc = current.removeAt(oldIndex);
      emitted.remove(name);
      changes.add(
        DocumentChange<T>._(
          type: DocumentChangeType.removed,
          oldIndex: oldIndex,
          newIndex: -1,
          doc: removedDoc.converted,
        ),
      );
    }

    for (final (name, doc) in upserted) {
      final old = emitted[name];
      var oldIndex = -1;
      if (old != null) {
        oldIndex = _lowerBound(current, old);
        current.removeAt(oldIndex);
      }
      final newIndex = _lowerBound(current, doc);
      final converted = _convert(doc);
      current.insert(newIndex, _EmittedDoc(doc, converted));
      emitted[name] = doc;
      changes.add(
        DocumentChange<T>._(
          type: old == null
              ? DocumentChangeType.added
              : DocumentChangeType.modified,
          oldIndex: oldIndex,
          newIndex: newIndex,
          doc: converted,
        ),
      );
    }

    return changes;
  }
}

class _EmittedDoc<T> {
  _EmittedDoc(this.raw, this.converted);

  final DocumentSnapshot<DocumentData> raw;
  final QueryDocumentSnapshot<T> converted;
}
