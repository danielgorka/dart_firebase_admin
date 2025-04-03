part of 'firestore.dart';

class _BatchGetResponse<T> {
  _BatchGetResponse(this.result, this.transaction);

  List<DocumentSnapshot<T>> result;
  List<int>? transaction;
}

class _DocumentReader<T> {
  _DocumentReader({
    required this.firestore,
    required this.documents,
    required this.fieldMask,
    this.transactionId,
    this.readTime,
    this.transactionOptions,
  })  : _outstandingDocuments = documents.map((e) => e._formattedName).toSet(),
        assert(
          [transactionId, readTime, transactionOptions].nonNulls.length <= 1,
          'Only transactionId or readTime or transactionOptions must be provided. transactionId = $transactionId, readTime = $readTime, transactionOptions = $transactionOptions',
        );

  List<int>? _retrievedTransactionId;
  final Firestore firestore;
  final List<DocumentReference<T>> documents;
  final List<FieldPath>? fieldMask;
  final List<int>? transactionId;
  final Timestamp? readTime;
  final firestore1.TransactionOptions? transactionOptions;
  final Set<String> _outstandingDocuments;
  final _retreivedDocuments = <String, DocumentSnapshot<DocumentData>>{};

  /// Invokes the BatchGetDocuments RPC and returns the results.
  Future<List<DocumentSnapshot<T>>> get() async {
    return _get().then((value) => value.result);
  }

  Future<_BatchGetResponse<T>> _get() async {
    await _fetchDocuments();

    // BatchGetDocuments doesn't preserve document order. We use the request
    // order to sort the resulting documents.
    final orderedDocuments = <DocumentSnapshot<T>>[];

    for (final docRef in documents) {
      final document = _retreivedDocuments[docRef._formattedName];
      if (document != null) {
        // Recreate the DocumentSnapshot with the DocumentReference
        // containing the original converter.
        final finalDoc = _DocumentSnapshotBuilder(docRef)
          ..fieldsProto = document._fieldsProto
          ..createTime = document.createTime
          ..readTime = document.readTime
          ..updateTime = document.updateTime;

        orderedDocuments.add(finalDoc.build());
      } else {
        throw StateError('Did not receive document for "${docRef.path}".');
      }
    }
    return _BatchGetResponse<T>(orderedDocuments, _retrievedTransactionId);
  }

  Future<void> _fetchDocuments() async {
    if (_outstandingDocuments.isEmpty) return;

    final request = firestore1.BatchGetDocumentsRequest(
      database: firestore._formattedDatabaseName,
      documents: _outstandingDocuments.toList(),
      mask: fieldMask.let((fieldMask) {
        return firestore1.DocumentMask(
          fieldPaths: fieldMask.map((e) => e._formattedName).toList(),
        );
      }),
      transaction: transactionId,
      newTransaction: transactionOptions,
      readTime: readTime?._toProto().timestampValue,
    );

    var resultCount = 0;
    try {
      final documents = await firestore._client.v1((client) async {
        return client.batchGetDocuments(request);
      }).catchError(_handleException);

      await for (final response in documents) {
        DocumentSnapshot<DocumentData>? documentSnapshot;

        if (response.transaction.isNotEmpty) {
          this._retrievedTransactionId = response.transaction;
        }

        if (response.hasFound()) {
          documentSnapshot = DocumentSnapshot._fromDocument(
            response.found,
            response.readTime,
            firestore,
          );
        } else if (response.hasMissing()) {
          final missing = response.missing;
          documentSnapshot = DocumentSnapshot._missing(
            missing,
            response.readTime,
            firestore,
          );
        }

        if (documentSnapshot != null) {
          final path = documentSnapshot.ref._formattedName;
          _outstandingDocuments.remove(path);
          _retreivedDocuments[path] = documentSnapshot;
          resultCount++;
        }
      }
    } on FirebaseFirestoreAdminException catch (firestoreError) {
      final shouldRetry = request.hasTransaction() &&
          request.hasNewTransaction() &&
          // Only retry if we made progress.
          resultCount > 0 &&
          // Don't retry permanent errors.
          StatusCode.batchGetRetryCodes
              .contains(firestoreError.errorCode.statusCode);
      if (shouldRetry) {
        return _fetchDocuments();
      } else {
        rethrow;
      }
    }
  }
}
