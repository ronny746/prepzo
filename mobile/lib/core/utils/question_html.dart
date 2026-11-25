/// Pure helpers that turn stored question / option / solution HTML into what
/// [MathHtmlRenderer] shows. Kept free of Flutter imports so they are
/// unit-tested (test/question_html_test.dart).
library;

/// Option texts that are only a label ("A", "(B)", "3.", "Option C") or
/// empty: imports create them for typed-answer questions or when the real
/// options were written inside the question text.
bool isDummyOptionText(String txt) {
  final clean = txt
      .replaceAll(RegExp(r'&nbsp;|\u00A0'), ' ')
      .replaceAll(
        RegExp(r'</?(?:p|div|span|br)\b[^>]*>', caseSensitive: false),
        '',
      )
      .trim();
  return clean.isEmpty ||
      RegExp(
        r'^(?:\([A-Da-d1-4]\)|[A-Da-d1-4][.)]?|option\s*[A-Da-d1-4])$',
        caseSensitive: false,
      ).hasMatch(clean);
}

String _optionRawText(Map<String, dynamic> opt) =>
    (opt['text'] ??
            opt['optionText'] ??
            opt['value'] ??
            opt['title'] ??
            opt['content'] ??
            opt['statement'] ??
            '')
        .toString();

String? _optionImage(Map<String, dynamic> opt) {
  final v = opt['imageUrl'] ?? opt['image'] ?? opt['img'];
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

bool _isDummyOption(Map<String, dynamic> opt) =>
    _optionImage(opt) == null && isDummyOptionText(_optionRawText(opt));

const _typedTypes = {'INTEGER', 'NUMERICAL', 'SUBJECTIVE', 'FILL_BLANKS'};

/// HTML for one option: its text exactly as stored (no label is stripped:
/// "3.32 mm", "A.P." and "(D) and (E)" are real content), plus its image.
String optionHtml(Map<String, dynamic> opt) {
  var text = _optionRawText(opt).trim();
  final img = _optionImage(opt);
  if (img != null &&
      !text.toLowerCase().contains('<img') &&
      !text.contains(img)) {
    final tag = '<img src="${img.replaceAll('"', '&quot;')}" />';
    text = text.isEmpty ? tag : '$text<br/>$tag';
  }
  return text;
}

final RegExp _labelRe = RegExp(
  // A label is "(A)".."(D)", "(1)".."(4)" or "A."/"A)".."D." followed by a
  // space, at the start or after a space/tag. Bare "1." is never a label: it
  // is the start of numbers like 1.5 or 3.32.
  r'(?:^|(?<=[\s>]))(?:\(([A-D1-4])\)|([A-D])[.)](?=\s|&nbsp;))',
);

/// Splits options out of the question text, only when the question has
/// placeholder options (every option empty or a bare label) and the text
/// holds a proper (A), (B), (C)... sequence. Typed-answer questions with
/// placeholder options get no options, so they show the answer box.
Map<String, dynamic> parseQuestionTextAndOptions(
  String rawQuestionText,
  List<Map<String, dynamic>> existingOptions, {
  String type = 'MCQ',
}) {
  final t = type.toUpperCase();
  final allDummy =
      existingOptions.isNotEmpty && existingOptions.every(_isDummyOption);
  if (_typedTypes.contains(t)) {
    return {
      'questionText': rawQuestionText,
      'options': allDummy ? <Map<String, dynamic>>[] : existingOptions,
    };
  }
  if (!allDummy || rawQuestionText.isEmpty) {
    return {'questionText': rawQuestionText, 'options': existingOptions};
  }

  // Walk the labels in order: A/1, then B/2, ... Anything else is content.
  final picked = <RegExpMatch>[];
  for (final m in _labelRe.allMatches(rawQuestionText)) {
    final label = m.group(1) ?? m.group(2)!;
    final index = RegExp(r'\d').hasMatch(label)
        ? int.parse(label) - 1
        : label.codeUnitAt(0) - 65;
    if (index == picked.length) picked.add(m);
  }
  final wanted = existingOptions.length.clamp(2, 4);
  if (picked.length < wanted) {
    return {'questionText': rawQuestionText, 'options': existingOptions};
  }

  String clean(String s) => s
      .replaceAll(
        RegExp(r'^(?:\s|<br\s*/?>|</?(?:p|div)[^>]*>)+', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'(?:\s|<br\s*/?>|</?(?:p|div)[^>]*>)+$', caseSensitive: false),
        '',
      )
      .trim();

  final options = <Map<String, dynamic>>[];
  for (var i = 0; i < picked.length; i++) {
    final end = i + 1 < picked.length
        ? picked[i + 1].start
        : rawQuestionText.length;
    final base = i < existingOptions.length
        ? Map<String, dynamic>.from(existingOptions[i])
        : <String, dynamic>{};
    final id =
        base['_id'] ?? base['id'] ?? 'opt_${String.fromCharCode(65 + i)}_$i';
    base['_id'] = id;
    base['id'] = id;
    base['text'] = clean(rawQuestionText.substring(picked[i].end, end));
    options.add(base);
  }
  final prompt = clean(rawQuestionText.substring(0, picked.first.start));
  return {
    'questionText': prompt.isEmpty ? rawQuestionText : prompt,
    'options': options,
  };
}

/// True when the content needs the WebView (markup, TeX, entities or a
/// combining vector arrow). Plain text is drawn natively: far cheaper.
bool needsWebView(String content) =>
    RegExp(r'<[a-zA-Z/!]|\\|\$|&[a-zA-Z#0-9]+;|\u20D7').hasMatch(content) ||
    _proseVectorRe.hasMatch(content);

// A vector typed as a letter followed by an arrow ("a→", as the question
// bank stores it). Only a single letter not glued to other letters or digits
// on either side, so reaction arrows like "A→B" or "2H₂→" are left alone.
final RegExp _proseVectorRe = RegExp(
  r'(?<![A-Za-z0-9])([A-Za-z])\u2192(?![A-Za-z0-9])',
);

// The same in MathML: <mi>a</mi><mo>→</mo> becomes an accent over the letter.
final RegExp _mathmlVectorRe = RegExp(
  r'<mi>\s*([A-Za-z])\s*</mi>\s*<mo>\s*(?:\u2192|&rarr;|&#8594;|&#x2192;)\s*</mo>',
);

/// Makes every `<img src>` absolute: "/x.png" and "uploads/x.png" are joined
/// to [webUrl], "//host/x" gets https, absolute/data URLs are left alone.
String resolveImageSources(String html, String webUrl) {
  final base = webUrl.replaceFirst(RegExp(r'/+$'), '');
  return html.replaceAllMapped(
    RegExp(
      r'''(<img\b[^>]*?\bsrc\s*=\s*)(["'])(.*?)\2''',
      caseSensitive: false,
    ),
    (m) {
      final url = m.group(3)!.trim();
      final lower = url.toLowerCase();
      String resolved;
      if (lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('data:') ||
          lower.startsWith('blob:')) {
        resolved = url;
      } else if (url.startsWith('//')) {
        resolved = 'https:$url';
      } else if (url.startsWith('/')) {
        resolved = '$base$url';
      } else if (url.isEmpty) {
        resolved = url;
      } else {
        resolved = '$base/$url';
      }
      return '${m.group(1)}${m.group(2)}$resolved${m.group(2)}';
    },
  );
}

/// Image URLs inside [html] (after [resolveImageSources]).
List<String> imageSources(String html) => RegExp(
  r'''<img\b[^>]*?\bsrc\s*=\s*(["'])(.*?)\1''',
  caseSensitive: false,
).allMatches(html).map((m) => m.group(2)!).toList();

final RegExp _mathSegmentRe = RegExp(
  r'\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\)|\$[^$\n]+?\$|<math\b[\s\S]*?</math>',
  caseSensitive: false,
);

final RegExp _texCommandRe = RegExp(r'\\[a-zA-Z]+');

/// Wraps bare TeX commands in prose (e.g. "If \vec{a} = 2\hat{i}") in
/// \( \) so MathJax renders them, without turning the whole sentence into
/// one unbreakable math line.
String _wrapBareTex(String prose) {
  if (!RegExp(r'\\[a-zA-Z]').hasMatch(prose)) return prose;
  // Only text between tags; never touch attributes.
  return prose.splitMapJoin(
    RegExp(r'<[^>]*>'),
    onMatch: (m) => m.group(0)!,
    onNonMatch: (text) {
      if (!RegExp(r'\\[a-zA-Z]').hasMatch(text)) return text;
      // \left..\right and environments must stay in one piece.
      if (RegExp(r'\\(?:left|begin)\b').hasMatch(text)) {
        final first = text.indexOf(RegExp(r'\S*\\[a-zA-Z]'));
        final lastCmd = RegExp(r'\\[a-zA-Z]+').allMatches(text).last;
        final end = _texChunkEnd(text, lastCmd.end);
        return '${text.substring(0, first)}\\(${text.substring(first, end)}\\)${text.substring(end)}';
      }
      final out = StringBuffer();
      var i = 0;
      while (i < text.length) {
        final m = _texCommandRe.allMatches(text, i).firstOrNull;
        if (m == null) {
          out.write(text.substring(i));
          break;
        }
        var start = m.start;
        while (start > i && !RegExp(r'[\s(]').hasMatch(text[start - 1])) {
          start--;
        }
        final end = _texChunkEnd(text, m.end);
        out
          ..write(text.substring(i, start))
          ..write('\\(')
          ..write(text.substring(start, end))
          ..write('\\)');
        i = end;
      }
      return out.toString();
    },
  );
}

/// End of a TeX chunk starting after a command: balanced {...}/[...] groups,
/// ^ / _ scripts and any following non-space characters.
int _texChunkEnd(String s, int from) {
  var i = from;
  var depth = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      if (depth == 0) break;
      depth--;
    } else if (depth == 0 && (RegExp(r'\s').hasMatch(c) || c == '<')) {
      // "\frac {a}" style: a space directly before a group continues it.
      final next = i + 1 < s.length ? s[i + 1] : '';
      if (c == ' ' && (next == '{' || next == '^' || next == '_')) {
        i++;
        continue;
      }
      break;
    }
    i++;
  }
  // Drop trailing sentence punctuation.
  while (i > from && RegExp(r'[,.;:!?)]').hasMatch(s[i - 1]) && depth == 0) {
    final open = '('.allMatches(s.substring(from, i)).length;
    final close = ')'.allMatches(s.substring(from, i)).length;
    if (s[i - 1] == ')' && close <= open) break;
    i--;
  }
  return i;
}

/// Content ready for the WebView: double-escaped TeX fixed, combining vector
/// arrows drawn above their letter, bare TeX wrapped, image URLs absolute.
String prepareQuestionHtml(String raw, {required String webUrl}) {
  if (raw.trim().isEmpty) return '';
  var text = raw
      // Some imports store "\\vec" (escaped twice): MathJax would print "vec".
      .replaceAllMapped(
        RegExp(r'\\\\([a-zA-Z]{2,})'),
        (m) => '\\${m.group(1)}',
      );

  text = text.splitMapJoin(
    _mathSegmentRe,
    onMatch: (m) {
      final seg = m.group(0)!;
      if (seg.toLowerCase().startsWith('<math')) {
        return seg.replaceAllMapped(
          _mathmlVectorRe,
          (v) =>
              '<mover accent="true"><mi>${v.group(1)}</mi><mo stretchy="false">\u2192</mo></mover>',
        );
      }
      // "a⃗" (letter + U+20D7) inside TeX: MathJax would print the arrow
      // after the letter. \vec puts it above.
      return seg
          .replaceAllMapped(
            RegExp(r'([A-Za-z0-9])\u20D7'),
            (v) => '\\vec{${v.group(1)}}',
          )
          .replaceAllMapped(_proseVectorRe, (v) => '\\vec{${v.group(1)}}');
    },
    onNonMatch: (prose) => _wrapBareTex(
      prose
          .replaceAllMapped(
            RegExp(r'([A-Za-z0-9])\u20D7'),
            (v) => '<span class="vec">${v.group(1)}</span>',
          )
          .replaceAllMapped(
            _proseVectorRe,
            (v) => '<span class="vec">${v.group(1)}</span>',
          ),
    ),
  );
  return resolveImageSources(text, webUrl);
}

/// Text for the native (non-WebView) path.
String plainQuestionText(String content) => content
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .trim();
