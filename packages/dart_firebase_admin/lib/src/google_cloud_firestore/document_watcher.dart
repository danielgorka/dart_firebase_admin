part of 'firestore.dart';

class _DocumentWatcher<T> {
  _DocumentWatcher({
    required this.firestore,
    required this.document,
    void Function()? onDone,
  }) {
    final documentsTarget = firestore1.Target(
      documents: firestore1.Target_DocumentsTarget(
        documents: [document._formattedName],
      ),
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
  final DocumentReference<T> document;

  late _ListenStreamWrapper _streamWrapper;

  Stream<DocumentSnapshot<T>> get stream =>
      _mapDocumentSnapshotStream(_streamWrapper.stream);

  Stream<DocumentSnapshot<T>> _mapDocumentSnapshotStream(
    Stream<firestore1.ListenResponse> listenRequestStream,
  ) {
    return listenRequestStream
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
              return DocumentSnapshot._fromDocument(
                response.documentChange.document,
                null,
                firestore,
              );
            }

            if (response.hasDocumentRemove()) {
              return DocumentSnapshot._missing(
                response.documentRemove.document,
                response.documentRemove.readTime,
                firestore,
              );
            }

            if (response.hasDocumentDelete()) {
              return DocumentSnapshot._missing(
                response.documentDelete.document,
                response.documentDelete.readTime,
                firestore,
              );
            }

            return null;
          },
        )
        .whereNotNull()
        .map(
          (snapshot) {
            // Recreate the DocumentSnapshot with the DocumentReference
            // containing the original converter.
            final finalDoc = _DocumentSnapshotBuilder(document)
              ..fieldsProto = snapshot._fieldsProto
              ..createTime = snapshot.createTime
              ..readTime = snapshot.readTime
              ..updateTime = snapshot.updateTime;

            return finalDoc.build();
          },
        );
  }
}

/// The number of retries to attempt when a stream throws an error.
const maxStreamReconnectRetries = 5;

class _ListenStreamWrapper {
  _ListenStreamWrapper.create(
    this._listenRequest,
    this.responseStreamFactory, {
    required this.onDone,
  }) {
    _listenResponseStreamController =
        StreamController<firestore1.ListenResponse>.broadcast(
      // Only when the response stream is listened to, we start the request stream.
      onListen: _retry,
      onCancel: () {
        // We close the request stream if there are no more listeners to the response stream.
        _errors.clear();
        _responseStreamSubscription?.cancel();
        close();
      },
    );
  }

  final void Function() onDone;

  final _errors = <(Object, StackTrace?)>[];
  final firestore1.ListenRequest _listenRequest;
  final Stream<firestore1.ListenResponse> Function(
    Stream<firestore1.ListenRequest>,
  ) responseStreamFactory;
  late StreamSubscription<firestore1.ListenResponse>?
      _responseStreamSubscription;
  late StreamController<firestore1.ListenRequest>
      _listenRequestStreamController;
  late StreamController<firestore1.ListenResponse>
      _listenResponseStreamController;
  final Map<String, DocumentSnapshot<DocumentData>> _documentMap = {};

  Map<String, DocumentSnapshot<DocumentData>> get documentMap => _documentMap;

  Timestamp? readTime;

  Stream<firestore1.ListenResponse> get stream =>
      _listenResponseStreamController.stream;

  void _retry() {
    _listenRequestStreamController =
        StreamController<firestore1.ListenRequest>();
    final responseStream = responseStreamFactory(
      _listenRequestStreamController.stream,
    );

    _responseStreamSubscription = responseStream.listen(
      (value) {
        // When we receive a new event, we reset the errors, because
        // max connection retries are only incremented for consecutive errors.
        _errors.clear();
        _listenResponseStreamController.add(value);
      },
      onDone: _listenResponseStreamController.close,
      onError: (Object error, StackTrace stackTrace) {
        _responseStreamSubscription!.cancel();
        _responseStreamSubscription = null;

        _errors.add((error, stackTrace));

        if (_errors.length == maxStreamReconnectRetries) {
          for (final e in _errors) {
            _listenResponseStreamController.addError(e.$1, e.$2);
          }
          close();
        } else {
          _retry();
        }
      },
    );
    _listenRequestStreamController.add(_listenRequest);
  }

  void close() {
    _listenRequestStreamController.close();
    _listenResponseStreamController.close();
    onDone();
  }
}
