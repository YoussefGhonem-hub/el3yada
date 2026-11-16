import 'package:el3yada/core/validation/map_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same cases as backend/tests/El3yada.Api.Tests/MapLinksTests.cs.
void main() {
  test('accepts Google Maps links', () {
    for (final link in [
      'https://maps.app.goo.gl/AbCd1234XyZ',
      'https://maps.app.goo.gl/AbCd1234XyZ?g_st=iw',
      'http://maps.app.goo.gl/AbCd1234XyZ',
      'HTTPS://MAPS.APP.GOO.GL/AbCd1234XyZ',
      'https://goo.gl/maps/AbCd1234XyZ',
      'https://maps.google.com/?q=30.0444,31.2357',
      'https://maps.google.com.eg/maps?q=clinic',
      'https://www.google.com/maps/place/Clinic/@30.0444,31.2357,17z',
      'https://www.google.com/maps/search/?api=1&query=30.038000,31.211000',
      'https://google.com/maps?q=30.0444,31.2357',
      'https://www.google.com.eg/maps/place/عيادة/@30.04,31.23,17z',
      'https://www.google.co.uk/maps/@30.04,31.23,15z',
      'https://www.google.de/maps',
      '  https://maps.app.goo.gl/AbCd1234XyZ  ',
    ]) {
      expect(MapLinks.isGoogleMaps(link), isTrue, reason: link);
    }
  });

  test('refuses anything else', () {
    for (final link in [
      '',
      'maps.app.goo.gl/AbCd1234XyZ',
      'ftp://maps.app.goo.gl/AbCd1234XyZ',
      'javascript:alert(1)',
      'https://maps.app.goo.gl/',
      'https://goo.gl/AbCd1234',
      'https://goo.gl/maps/',
      'https://www.google.com/search?q=clinic',
      'https://www.google.com/mapsxyz',
      'https://www.google.com.evil.com/maps/place/x',
      'https://google.com@evil.com/maps',
      'https://evil.com/?u=https://maps.app.goo.gl/x',
      'https://maps.google.com.evil.com/x',
      'https://notgoogle.com/maps',
      'https://maps.app.goo.gl:8443/AbCd',
      'https://www.facebook.com/maps/clinic',
      'Clinic https://maps.app.goo.gl/AbCd1234XyZ',
      '30.0444, 31.2357',
    ]) {
      expect(MapLinks.isGoogleMaps(link), isFalse, reason: link);
    }
  });

  test('extract keeps only the link from a share text', () {
    expect(MapLinks.extract('عيادة د. سامي\nhttps://maps.app.goo.gl/AbCd1234'), 'https://maps.app.goo.gl/AbCd1234');
    expect(MapLinks.extract('Dr Sami Clinic https://maps.app.goo.gl/AbCd1234?g_st=ic'), 'https://maps.app.goo.gl/AbCd1234?g_st=ic');
    // Punctuation and invisible direction marks after the link are not part of it.
    expect(MapLinks.extract('المكان هنا: https://maps.app.goo.gl/AbCd1234.'), 'https://maps.app.goo.gl/AbCd1234');
    expect(MapLinks.extract('«https://maps.app.goo.gl/AbCd1234»'), 'https://maps.app.goo.gl/AbCd1234');
    final rlm = String.fromCharCode(0x200F);
    expect(MapLinks.extract('https://maps.app.goo.gl/AbCd1234$rlm عيادة'), 'https://maps.app.goo.gl/AbCd1234');
    // A ")" stays when the link opened one.
    expect(
      MapLinks.extract('(see https://www.google.com/maps/place/Clinic+(Dr+Sami))'),
      'https://www.google.com/maps/place/Clinic+(Dr+Sami)',
    );
    // A Google Maps link is preferred over another link in the same text.
    expect(
      MapLinks.extract('https://example.com/menu and https://maps.app.goo.gl/AbCd1234'),
      'https://maps.app.goo.gl/AbCd1234',
    );
    // No link: the text comes back trimmed, and the field shows the error.
    expect(MapLinks.extract('  عيادة د. سامي  '), 'عيادة د. سامي');
  });
}
