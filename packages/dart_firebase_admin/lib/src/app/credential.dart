part of '../app.dart';

@internal
const envSymbol = #_envSymbol;

class _RequestImpl extends BaseRequest {
  _RequestImpl(super.method, super.url, [Stream<List<int>>? stream])
      : _stream = stream ?? const Stream.empty();

  final Stream<List<int>> _stream;

  @override
  ByteStream finalize() {
    super.finalize();
    return ByteStream(_stream);
  }
}

/// Will close the underlying `http.Client` depending on a constructor argument.
class _EmulatorClient extends BaseClient {
  _EmulatorClient(this.client);

  final Client client;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Make new request object and perform the authenticated request.
    final modifiedRequest = _RequestImpl(
      request.method,
      request.url,
      request.finalize(),
    );
    modifiedRequest.headers.addAll(request.headers);
    modifiedRequest.headers['Authorization'] = 'Bearer owner';

    return client.send(modifiedRequest);
  }

  @override
  void close() {
    client.close();
    super.close();
  }
}

/// Authentication information for Firebase Admin SDK.
class Credential {
  Credential._({
    this.serviceAccountCredentials,
    this.serviceAccountId,
    this.serviceAccountJson,
  }) : assert(
          serviceAccountId == null || serviceAccountCredentials == null,
          'Cannot specify both serviceAccountId and serviceAccountCredentials',
        );

  /// Log in to firebase from a service account file.
  factory Credential.fromServiceAccount(File serviceAccountFile) {
    final content = serviceAccountFile.readAsStringSync();

    final json = jsonDecode(content);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Invalid service account file');
    }

    final serviceAccountCredentials =
        auth.ServiceAccountCredentials.fromJson(json);

    return Credential._(
      serviceAccountCredentials: serviceAccountCredentials,
      serviceAccountJson: content,
    );
  }

  /// Log in to firebase from a service account file parameters.
  factory Credential.fromServiceAccountParams({
    required String clientId,
    required String privateKey,
    required String email,
  }) {
    final serviceAccountCredentials = auth.ServiceAccountCredentials(
      email,
      ClientId(clientId),
      privateKey,
    );

    return Credential._(
      serviceAccountCredentials: serviceAccountCredentials,
      serviceAccountJson: jsonEncode({
        'type': 'service_account',
        'client_id': clientId,
        'private_key': privateKey,
        'client_email': email,
      }),
    );
  }

  /// Log in to firebase using the environment variable.
  factory Credential.fromApplicationDefaultCredentials({
    String? serviceAccountId,
  }) {
    ServiceAccountCredentials? creds;
    String? serviceAccountJson;

    final env =
        Zone.current[envSymbol] as Map<String, String>? ?? Platform.environment;
    final maybeConfig = env['GOOGLE_APPLICATION_CREDENTIALS'];
    if (maybeConfig != null && File(maybeConfig).existsSync()) {
      try {
        serviceAccountJson = File(maybeConfig).readAsStringSync();
        final decodedValue = jsonDecode(serviceAccountJson);
        if (decodedValue is Map) {
          creds = ServiceAccountCredentials.fromJson(decodedValue);
        }
      } on FormatException catch (_) {}
    }

    return Credential._(
      serviceAccountCredentials: creds,
      serviceAccountJson: serviceAccountJson,
      serviceAccountId: serviceAccountId,
    );
  }

  @internal
  final String? serviceAccountId;

  @internal
  final auth.ServiceAccountCredentials? serviceAccountCredentials;

  @internal
  final String? serviceAccountJson;

  grpc.BaseAuthenticator authenticatorFor(List<String> scopes) =>
      serviceAccountJson != null
          ? grpc.ServiceAccountAuthenticator(
              serviceAccountJson!,
              scopes,
            )
          : grpc.ComputeEngineAuthenticator();
}
