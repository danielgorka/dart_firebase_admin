import 'package:dart_firebase_admin/src/auth.dart';
import 'package:test/test.dart';

void main() {
  group('DecodedIdToken', () {
    test('.fromMap', () async {
      const map = {
        'aud': 'mock-aud',
        'auth_time': 1,
        'email': 'mock-email',
        'email_verified': true,
        'exp': 1,
        'firebase': {
          'identities': {
            'email': 'mock-email',
          },
          'sign_in_provider': 'mock-sign-in-provider',
          'sign_in_second_factor': 'mock-sign-in-second-factor',
          'second_factor_identifier': 'mock-second-factor-identifier',
          'tenant': 'mock-tenant',
        },
        'iat': 1,
        'iss': 'mock-iss',
        'phone_number': 'mock-phone-number',
        'picture': 'mock-picture',
        'sub': 'mock-sub',
        'custom_property': 'custom-value',
      };
      final idToken = DecodedIdToken.fromMap(map);
      expect(idToken.aud, 'mock-aud');
      expect(idToken.authTime, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(idToken.email, 'mock-email');
      expect(idToken.emailVerified, true);
      expect(idToken.exp, 1);
      expect(idToken.firebase.identities, {'email': 'mock-email'});
      expect(idToken.firebase.signInProvider, 'mock-sign-in-provider');
      expect(idToken.firebase.signInSecondFactor, 'mock-sign-in-second-factor');
      expect(
        idToken.firebase.secondFactorIdentifier,
        'mock-second-factor-identifier',
      );
      expect(idToken.firebase.tenant, 'mock-tenant');
      expect(idToken.iat, 1);
      expect(idToken.iss, 'mock-iss');
      expect(idToken.phoneNumber, 'mock-phone-number');
      expect(idToken.picture, 'mock-picture');
      expect(idToken.sub, 'mock-sub');
      expect(idToken.uid, 'mock-sub');
      expect(idToken.claims, map);
    });
  });
}
