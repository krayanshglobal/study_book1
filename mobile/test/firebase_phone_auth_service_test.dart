import 'package:cmaths_mobile/app/core/services/firebase_phone_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Indian phone normalization', () {
    final service = FirebasePhoneAuthService();

    test('normalizes a ten digit number', () {
      expect(service.normalizeIndianPhone('98765 43210'), '+919876543210');
    });

    test('preserves the Indian country code', () {
      expect(service.normalizeIndianPhone('+91-98765-43210'), '+919876543210');
    });

    test('rejects invalid lengths', () {
      expect(
        () => service.normalizeIndianPhone('12345'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => service.normalizeIndianPhone('19876543210'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
