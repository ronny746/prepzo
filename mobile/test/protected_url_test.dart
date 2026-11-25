import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/utils/protected_url.dart';

void main() {
  const web = 'https://theprepzo.com';

  test('relative path resolves against webUrl', () {
    expect(
      resolveResourceUrl('/api/v1/resources/stream/abc', webUrl: web),
      'https://theprepzo.com/api/v1/resources/stream/abc',
    );
    expect(resolveResourceUrl('/x', webUrl: '$web/'), '$web/x');
  });

  test('absolute URL is untouched', () {
    expect(
      resolveResourceUrl('https://example.com/a.pdf', webUrl: web),
      'https://example.com/a.pdf',
    );
  });

  test('protected detection', () {
    expect(
      isProtectedAppUrl('/api/v1/resources/stream/abc', webUrl: web),
      isTrue,
    );
    expect(isProtectedAppUrl('https://theprepzo.com/x', webUrl: web), isTrue);
    expect(
      isProtectedAppUrl('https://example.com/a.pdf', webUrl: web),
      isFalse,
    );
    expect(
      isProtectedAppUrl('https://evil.com/theprepzo.com', webUrl: web),
      isFalse,
    );
    expect(isProtectedAppUrl('https://youtu.be/xyz', webUrl: web), isFalse);
  });

  test('cleartext, other port and userinfo never count as protected', () {
    expect(isProtectedAppUrl('http://theprepzo.com/x', webUrl: web), isFalse);
    expect(
      isProtectedAppUrl('https://theprepzo.com:8443/x', webUrl: web),
      isFalse,
    );
    expect(
      isProtectedAppUrl('https://u:p@theprepzo.com/x', webUrl: web),
      isFalse,
    );
    expect(
      isProtectedAppUrl('https://theprepzo.com@evil.com/x', webUrl: web),
      isFalse,
    );
  });
}
