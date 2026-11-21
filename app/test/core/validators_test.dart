import 'package:el3yada/core/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeEgyptianMobile', () {
    test('accepts the usual formats and returns E.164', () {
      expect(
        Validators.normalizeEgyptianMobile('01012345678'),
        '+201012345678',
      );
      expect(
        Validators.normalizeEgyptianMobile('+201112345678'),
        '+201112345678',
      );
      expect(
        Validators.normalizeEgyptianMobile('00201212345678'),
        '+201212345678',
      );
      expect(
        Validators.normalizeEgyptianMobile('201512345678'),
        '+201512345678',
      );
      expect(
        Validators.normalizeEgyptianMobile('010 1234 5678'),
        '+201012345678',
      );
    });

    test('accepts Arabic-Indic digits', () {
      expect(
        Validators.normalizeEgyptianMobile('٠١٠١٢٣٤٥٦٧٨'),
        '+201012345678',
      );
    });

    test('rejects invalid numbers', () {
      expect(Validators.normalizeEgyptianMobile('01312345678'), isNull);
      expect(Validators.normalizeEgyptianMobile('0101234567'), isNull);
      expect(Validators.normalizeEgyptianMobile('abc'), isNull);
    });
  });

  group('normalizeIdentifier', () {
    test('treats input with @ as an email', () {
      expect(
        Validators.normalizeIdentifier(' Doctor@Example.com '),
        'doctor@example.com',
      );
      expect(Validators.normalizeIdentifier('not-an@email'), isNull);
    });

    test('treats other input as a mobile number', () {
      expect(Validators.normalizeIdentifier('01000000002'), '+201000000002');
    });
  });
}
