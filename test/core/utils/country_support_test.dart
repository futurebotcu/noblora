import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/core/utils/country_support.dart';

void main() {
  group('CountrySupport.isSupported', () {
    test('TH is supported', () {
      expect(CountrySupport.isSupported('TH'), isTrue);
    });

    test('VN is supported', () {
      expect(CountrySupport.isSupported('VN'), isTrue);
    });

    test('PH is supported', () {
      expect(CountrySupport.isSupported('PH'), isTrue);
    });

    test('TR is NOT supported (V1 scope is SE Asia only)', () {
      expect(CountrySupport.isSupported('TR'), isFalse);
    });

    test('null is NOT supported (unknown defaults to false)', () {
      expect(CountrySupport.isSupported(null), isFalse);
    });

    test('lowercase th is NOT supported (must be ISO 2-letter UPPER)', () {
      expect(CountrySupport.isSupported('th'), isFalse);
    });
  });

  group('CountrySupport.isUserActiveInRegion', () {
    test('TH home + travel off → allowed', () {
      expect(
        CountrySupport.isUserActiveInRegion(
          country: 'TH',
          travelMode: false,
          travelCountry: null,
        ),
        isTrue,
      );
    });

    test('TR home + travel off → blocked', () {
      expect(
        CountrySupport.isUserActiveInRegion(
          country: 'TR',
          travelMode: false,
          travelCountry: null,
        ),
        isFalse,
      );
    });

    test('TR home + travel ON to TH → allowed (travel mode rescue)', () {
      expect(
        CountrySupport.isUserActiveInRegion(
          country: 'TR',
          travelMode: true,
          travelCountry: 'TH',
        ),
        isTrue,
      );
    });

    test('TR home + travel ON but to TR → blocked', () {
      expect(
        CountrySupport.isUserActiveInRegion(
          country: 'TR',
          travelMode: true,
          travelCountry: 'TR',
        ),
        isFalse,
      );
    });

    test('null home + travel ON to TH → allowed', () {
      // Onboarding edge-case: user lands without a resolved home country
      // but turns on travel mode pointing at a supported region.
      expect(
        CountrySupport.isUserActiveInRegion(
          country: null,
          travelMode: true,
          travelCountry: 'TH',
        ),
        isTrue,
      );
    });

    test('null home + travel ON but travelCountry null → blocked', () {
      // Travel mode toggled on but no destination set yet.
      expect(
        CountrySupport.isUserActiveInRegion(
          country: null,
          travelMode: true,
          travelCountry: null,
        ),
        isFalse,
      );
    });

    test('null home + travel OFF → blocked', () {
      expect(
        CountrySupport.isUserActiveInRegion(
          country: null,
          travelMode: false,
          travelCountry: null,
        ),
        isFalse,
      );
    });

    test('VN home (PH-targeted travel mode irrelevant) → allowed', () {
      // Home alone is enough; travel state is checked only when home fails.
      expect(
        CountrySupport.isUserActiveInRegion(
          country: 'VN',
          travelMode: true,
          travelCountry: 'TH',
        ),
        isTrue,
      );
    });
  });
}
