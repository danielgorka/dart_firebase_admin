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
        .map(
          (snapshots) => QuerySnapshot._(
            query: query,
            readTime: wrapper.readTime,
            docs: snapshots
                .map(
                  (snapshot) {
                    // Recreate the DocumentSnapshot with the DocumentReference
                    // containing the original converter.
                    final finalDoc = _DocumentSnapshotBuilder(
                      snapshot.ref.withConverter<T>(
                        fromFirestore:
                            query._queryOptions.converter.fromFirestore,
                        toFirestore: query._queryOptions.converter.toFirestore,
                      ),
                    )
                      ..fieldsProto = snapshot._fieldsProto
                      ..createTime = snapshot.createTime
                      ..readTime = snapshot.readTime
                      ..updateTime = snapshot.updateTime;

                    return finalDoc.build();
                  },
                )
                .cast<QueryDocumentSnapshot<T>>()
                .toList(),
          ),
        )
        .distinct();
  }
}
