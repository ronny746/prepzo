import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/services/deep_link_service.dart';

void main() {
  String? t(String url) => DeepLinkService.target(Uri.parse(url));

  test('course links on theprepzo.com map to a course id or slug', () {
    expect(
      t('https://theprepzo.com/explore-courses/shakti-test-series'),
      'shakti-test-series',
    );
    expect(
      t('https://www.theprepzo.com/course/6650aa11bb22cc33dd44ee55'),
      '6650aa11bb22cc33dd44ee55',
    );
    expect(t('https://theprepzo.com/student/course/abc123'), 'abc123');
    expect(t('https://theprepzo.com/checkout/abc123?x=1'), 'abc123');
    expect(t('https://theprepzo.com/explore-courses'), '');
  });

  test('other sites and pages are ignored', () {
    expect(t('https://example.com/explore-courses/x'), isNull);
    expect(t('https://theprepzo.com/privacy-policy'), isNull);
    expect(t('https://theprepzo.com/'), isNull);
    expect(t('prepzo://course/x'), isNull);
  });

  test('share link prefers the slug and falls back to the id', () {
    expect(
      DeepLinkService.courseUrl(id: 'abc', slug: 'jee-main-2027'),
      'https://theprepzo.com/course/jee-main-2027',
    );
    expect(
      DeepLinkService.courseUrl(id: 'abc'),
      'https://theprepzo.com/course/abc',
    );
  });
}
