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
    // Documents of the previously emitted snapshot, used to compute docChanges.
    var previousDocs = <DocumentSnapshot<DocumentData>>[];
    var hasEmitted = false;

    return wrapper.stream
        .map(
          (response) {
            if (response.hasTargetChange() &&
                response.targetChange.hasCause()) {
              // Handle error
              throw FirebaseFirestoreAdminException.fromServerError(
                serverErrorCode:
                    Code.values[response.targetChange.cause.code].name,
                message: response.targetChange.cause.message,
              );
            }

            if (response.hasTargetChange() &&
                response.targetChange.targetChangeType ==
                    firestore1.TargetChange_TargetChangeType.RESET) {
              // The backend will resend the full result set.
              wrapper.documentMap.clear();
            }

            if (response.hasDocumentChange()) {
              if (response.documentChange.removedTargetIds.isEmpty) {
                // Add the document to the map
                wrapper.documentMap[response.documentChange.document.name] =
                    DocumentSnapshot._fromDocument(
                  response.documentChange.document,
                  null,
                  firestore,
                );
              } else {
                // Remove the document from the map
                wrapper.documentMap
                    .remove(response.documentChange.document.name);
              }
            }

            if (response.hasDocumentDelete()) {
              // Remove the document from the map
              wrapper.documentMap.remove(response.documentDelete.document);
            }

            if (response.hasDocumentRemove()) {
              // Remove the document from the map
              wrapper.documentMap.remove(response.documentRemove.document);
            }

            if (response.hasTargetChange() &&
                !response.targetChange.hasTargetChangeType()) {
              // Emit update on target change without type
              // We need to sort the documents by the order specified in
              // the query as on update we don't get the order of the documents.
              wrapper.readTime =
                  Timestamp._fromProtoTimestamp(response.targetChange.readTime);
              return wrapper.documentMap.values.sorted(
                (a, b) => query
                    ._createBackendOrderBy()
                    .map((order) => order._compare(a, b))
                    .firstWhere(
                      (comparison) => comparison != 0,
                      orElse: () => 0,
                    ),
              );
            } else {
              // Don't emit anything until all documents are received
              return null;
            }
          },
        )
        .whereNotNull()
        .map((snapshots) {
          final changes = _computeChanges(previousDocs, snapshots);
          previousDocs = snapshots;

          // Like the official SDKs, only emit the first snapshot and then
          // snapshots that actually contain changes.
          if (hasEmitted && changes.isEmpty) return null;
          hasEmitted = true;

          return (snapshots, changes);
        })
        .whereNotNull()
        .map(
          (result) {
            final (snapshots, changes) = result;

            // Recreate the DocumentSnapshot with the DocumentReference
            // containing the original converter.
            QueryDocumentSnapshot<T> convert(
              DocumentSnapshot<DocumentData> snapshot,
            ) {
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

            return QuerySnapshot._(
              query: query,
              readTime: wrapper.readTime,
              docs: snapshots.map(convert).toList(),
              docChanges: [
                for (final change in changes)
                  DocumentChange<T>._(
                    type: change.type,
                    oldIndex: change.oldIndex,
                    newIndex: change.newIndex,
                    doc: convert(change.doc),
                  ),
              ],
            );
          },
        )
        .distinct();
  }

  int _compareDocs(
    DocumentSnapshot<DocumentData> a,
    DocumentSnapshot<DocumentData> b,
  ) {
    for (final order in query._createBackendOrderBy()) {
      final comparison = order._compare(a, b);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  /// Computes the changes between two ordered snapshots, the same way the
  /// official SDKs do: removals first (using old indexes), then additions
  /// and modifications (using indexes in the progressively updated set).
  List<_RawDocumentChange> _computeChanges(
    List<DocumentSnapshot<DocumentData>> previous,
    List<DocumentSnapshot<DocumentData>> next,
  ) {
    final previousByPath = {for (final doc in previous) doc.ref.path: doc};
    final nextByPath = {for (final doc in next) doc.ref.path: doc};

    final current = [...previous];
    final changes = <_RawDocumentChange>[];

    int indexOfPath(String path) =>
        current.indexWhere((doc) => doc.ref.path == path);

    int insert(DocumentSnapshot<DocumentData> doc) {
      var index = current.indexWhere((other) => _compareDocs(doc, other) < 0);
      if (index == -1) index = current.length;
      current.insert(index, doc);
      return index;
    }

    for (final doc in previous) {
      if (nextByPath.containsKey(doc.ref.path)) continue;
      final oldIndex = indexOfPath(doc.ref.path);
      current.removeAt(oldIndex);
      changes.add(
        _RawDocumentChange(DocumentChangeType.removed, doc, oldIndex, -1),
      );
    }

    for (final doc in next) {
      final old = previousByPath[doc.ref.path];
      if (old == null) {
        changes.add(
          _RawDocumentChange(DocumentChangeType.added, doc, -1, insert(doc)),
        );
      } else if (old.updateTime != doc.updateTime) {
        final oldIndex = indexOfPath(doc.ref.path);
        current.removeAt(oldIndex);
        changes.add(
          _RawDocumentChange(
            DocumentChangeType.modified,
            doc,
            oldIndex,
            insert(doc),
          ),
        );
      }
    }

    return changes;
  }
}

class _RawDocumentChange {
  _RawDocumentChange(this.type, this.doc, this.oldIndex, this.newIndex);

  final DocumentChangeType type;
  final DocumentSnapshot<DocumentData> doc;
  final int oldIndex;
  final int newIndex;
}
