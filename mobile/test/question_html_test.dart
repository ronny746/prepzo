import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/utils/question_html.dart';

void main() {
  const web = 'https://theprepzo.com';

  group('option text is shown as stored (retest New problem 1)', () {
    for (final text in [
      '3.32 mm',
      '2.00 M',
      '1.5 sq. units',
      '4.0',
      'A.P.',
      '(D) and (E)',
      '(A) only',
    ]) {
      test('"$text" keeps its start', () {
        expect(optionHtml({'text': text}), text);
      });
    }

    test('option image is added once', () {
      final html = optionHtml({'text': 'x', 'imageUrl': '/u/a.png'});
      expect(html, 'x<br/><img src="/u/a.png" />');
    });
  });

  group('question text is never cut at a number', () {
    const q =
        'The length is measured with an error of 1.25%. If the error in breadth is 2.5%, find the error in area.';
    final realOptions = [
      {'_id': 'a', 'text': '3.75%'},
      {'_id': 'b', 'text': '1.25%'},
    ];

    test('real options: text and options untouched', () {
      final r = parseQuestionTextAndOptions(q, realOptions);
      expect(r['questionText'], q);
      expect(r['options'], realOptions);
    });

    test('no options (typed answer): nothing is split out', () {
      final r = parseQuestionTextAndOptions(q, const [], type: 'INTEGER');
      expect(r['questionText'], q);
      expect(r['options'], isEmpty);
    });

    test('placeholder options + decimals: decimals are not labels', () {
      final dummies = [
        {'_id': '1', 'text': 'A'},
        {'_id': '2', 'text': 'B'},
      ];
      final r = parseQuestionTextAndOptions(q, dummies);
      expect(r['questionText'], q);
    });

    test('placeholder options + real (A)..(D) sequence are split', () {
      final dummies = List.generate(
        4,
        (i) => {'_id': 'id$i', 'text': String.fromCharCode(65 + i)},
      );
      final r = parseQuestionTextAndOptions(
        'Pick one. (A) 3.32 mm (B) 3.73 mm (C) 3.67 mm (D) 3.38 mm',
        dummies,
      );
      expect(r['questionText'], 'Pick one.');
      final opts = (r['options'] as List).cast<Map<String, dynamic>>();
      expect(opts.map((o) => o['text']), [
        '3.32 mm',
        '3.73 mm',
        '3.67 mm',
        '3.38 mm',
      ]);
      expect(opts.first['_id'], 'id0');
    });

    test('INTEGER question with placeholder options shows the answer box', () {
      final r = parseQuestionTextAndOptions('Find x.', [
        {'text': ''},
        {'text': '(B)'},
      ], type: 'INTEGER');
      expect(r['options'], isEmpty);
    });
  });

  group('prepareQuestionHtml', () {
    test('relative image URLs become absolute', () {
      final html = prepareQuestionHtml(
        '<p>Graph</p><img src="/uploads/g.png"><img src=\'q/2.png\'><img src="https://s3.x/a.png">',
        webUrl: web,
      );
      expect(imageSources(html), [
        '$web/uploads/g.png',
        '$web/q/2.png',
        'https://s3.x/a.png',
      ]);
    });

    test('combining vector arrow goes above the letter', () {
      expect(
        prepareQuestionHtml('vectors a⃗ and b⃗', webUrl: web),
        'vectors <span class="vec">a</span> and <span class="vec">b</span>',
      );
      expect(
        prepareQuestionHtml(r'$a⃗ + b$'.replaceAll(r'⃗', '⃗'), webUrl: web),
        r'$\vec{a} + b$',
      );
    });

    test('double-escaped TeX commands are repaired', () {
      expect(prepareQuestionHtml(r'$\\vec{a}$', webUrl: web), r'$\vec{a}$');
    });

    test('bare TeX is wrapped piece by piece, prose stays wrappable', () {
      final out = prepareQuestionHtml(
        r'If \vec{a} = 2\hat{i} + \hat{j}, find the projection.',
        webUrl: web,
      );
      expect(
        out,
        r'If \(\vec{a}\) = \(2\hat{i}\) + \(\hat{j}\), find the projection.',
      );
    });

    test('delimited maths is left alone', () {
      const s = r'Solve $x^2 = 1.5$ and \(y\).';
      expect(prepareQuestionHtml(s, webUrl: web), s);
    });

    test('plain numbers never need the WebView', () {
      expect(needsWebView('3.32 mm'), isFalse);
      expect(needsWebView(r'$x$'), isTrue);
      expect(needsWebView('<img src="a">'), isTrue);
    });
  });

  group('stored letter + arrow vectors', () {
    const web = 'https://theprepzo.com';
    test('prose "a→" gets the arrow above', () {
      final out = prepareQuestionHtml(
        'position vectors a→, b→ and c→ respectively',
        webUrl: web,
      );
      expect(out, contains('<span class="vec">a</span>'));
      expect(out, contains('<span class="vec">c</span>'));
      expect(out, isNot(contains('a\u2192')));
      expect(needsWebView('vectors a→ and b→'), isTrue);
    });
    test('MathML <mi>a</mi><mo>→</mo> becomes an accent', () {
      final out = prepareQuestionHtml(
        '<math><mrow><mo>[</mo><mi>a</mi><mo>→</mo><mi>b</mi><mo>→</mo><mo>]</mo></mrow></math>',
        webUrl: web,
      );
      expect(out, contains('<mover accent="true"><mi>a</mi>'));
      expect(out, contains('<mover accent="true"><mi>b</mi>'));
    });
    test('reaction arrows are left alone', () {
      expect(
        prepareQuestionHtml('A→B then 2H2→2H', webUrl: web),
        isNot(contains('vec')),
      );
    });
  });
}
