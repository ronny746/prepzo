class HtmlCleaner {
  static String clean(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    String text = raw;
    text = text.replaceAll(RegExp(r'&npsb;?', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), ' ');
    text = text.replaceAll('&#xa0;', ' ');
    text = text.replaceAll('&#160;', ' ');
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&apos;', "'");
    text = text.replaceAll('&deg;', '°');
    text = text.replaceAll('&plusmn;', '±');
    text = text.replaceAll('&times;', '×');
    text = text.replaceAll('&divide;', '÷');
    text = text.replaceAll('&micro;', 'µ');
    text = text.replaceAll('&mu;', 'μ');
    text = text.replaceAll('&alpha;', 'α');
    text = text.replaceAll('&beta;', 'β');
    text = text.replaceAll('&theta;', 'θ');
    text = text.replaceAll('&pi;', 'π');
    text = text.replaceAll('&omega;', 'ω');
    text = text.replaceAll('&lambda;', 'λ');
    text = text.replaceAll('&delta;', 'δ');
    text = text.replaceAll('&Delta;', 'Δ');
    text = text.replaceAll('&Omega;', 'Ω');
    text = text.replaceAll('&infin;', '∞');
    text = text.replaceAll('&le;', '≤');
    text = text.replaceAll('&ge;', '≥');
    text = text.replaceAll('&ne;', '≠');
    text = text.replaceAll('&approx;', '≈');
    return text.trim();
  }
}
