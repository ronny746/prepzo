import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/core/utils/question_html.dart';

/// Renders question / option / solution HTML with maths.
///
/// Plain text is drawn with a native [Text]. Anything with markup, TeX or
/// images goes through one small WebView that:
/// - wraps normal text to the card width; only a display equation that is
///   wider than the card scrolls sideways (or shrinks to fit when
///   [interactive] is false);
/// - reports its real height from the page (after MathJax and every image
///   finished), so maths and pictures are never cut off or left blank;
/// - uses MathJax's SVG output, which needs no web fonts, so a vector arrow
///   is always drawn above its letter;
/// - opens a tapped picture full screen, zoomable.
///
/// Set [interactive] to false inside a tappable card (an option): the
/// WebView then ignores touches so the whole card receives the tap.
class MathHtmlRenderer extends StatefulWidget {
  final String htmlContent;
  final double baseFontSize;
  final Color fontColor;
  final bool interactive;

  const MathHtmlRenderer({
    super.key,
    required this.htmlContent,
    this.baseFontSize = 16.0,
    this.fontColor = Colors.black87,
    this.interactive = true,
  });

  @override
  State<MathHtmlRenderer> createState() => _MathHtmlRendererState();
}

/// Heights already measured, so a card scrolled back into a lazy list opens
/// at its real size instead of jumping.
final LinkedHashMap<String, double> _heightCache = LinkedHashMap();
const int _heightCacheLimit = 400;

class _MathHtmlRendererState extends State<MathHtmlRenderer> {
  WebViewController? _controller;
  double? _contentHeight;
  bool _ready = false;
  Timer? _revealTimer;
  late String _prepared;
  late bool _usesWebView;

  String get _cacheKey =>
      '${widget.baseFontSize}|${widget.interactive}|${_prepared.hashCode}|${_prepared.length}';

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  void _setUp() {
    final raw = widget.htmlContent;
    _usesWebView = needsWebView(raw);
    _prepared = _usesWebView
        ? prepareQuestionHtml(raw, webUrl: AppConfig.webUrl)
        : plainQuestionText(raw);
    if (!_usesWebView) return;

    _contentHeight = _heightCache[_cacheKey];
    _ready = false;
    _revealTimer?.cancel();
    // Show whatever is there after a while even if MathJax never loads
    // (offline): raw TeX beats an empty box.
    _revealTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_ready) setState(() => _ready = true);
    });
    (_controller ??= _createController()).loadHtmlString(_buildHtml(_prepared));
  }

  WebViewController _createController() => WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.transparent)
    ..setNavigationDelegate(
      NavigationDelegate(
        // Question HTML must never navigate the box away.
        onNavigationRequest: (req) =>
            req.url.startsWith('about:') || req.url.startsWith('data:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    )
    ..addJavaScriptChannel('PrepzoHeight', onMessageReceived: _onHeight)
    ..addJavaScriptChannel(
      'PrepzoReady',
      onMessageReceived: (_) {
        if (mounted && !_ready) setState(() => _ready = true);
      },
    )
    ..addJavaScriptChannel(
      'PrepzoImage',
      onMessageReceived: (m) {
        if (mounted) _openImage(m.message);
      },
    );

  void _onHeight(JavaScriptMessage message) {
    final h = double.tryParse(message.message);
    if (!mounted || h == null || h <= 0) return;
    final height = h.ceilToDouble();
    _heightCache.remove(_cacheKey);
    _heightCache[_cacheKey] = height;
    if (_heightCache.length > _heightCacheLimit) {
      _heightCache.remove(_heightCache.keys.first);
    }
    if (_contentHeight == null || (height - _contentHeight!).abs() >= 1) {
      setState(() => _contentHeight = height);
    }
  }

  @override
  void didUpdateWidget(MathHtmlRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent ||
        oldWidget.baseFontSize != widget.baseFontSize ||
        oldWidget.fontColor != widget.fontColor ||
        oldWidget.interactive != widget.interactive) {
      _setUp();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _openImage(String src) => showZoomableImage(context, src);

  String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';

  String _buildHtml(String content) {
    final hex = _colorToHex(widget.fontColor);
    final size = widget.baseFontSize;
    final fit = widget.interactive ? '' : 'fit';
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<script>
function prepzoH(){
  var c=document.getElementById('c'); if(!c) return;
  var w=c.clientWidth;
  // Only a formula wider than the screen becomes its own scrollable block;
  // measure it inline first so one that fits stays inside the sentence.
  document.querySelectorAll('mjx-container').forEach(function(m){
    m.classList.remove('wide');
    var svg=m.querySelector('svg');
    var fw=svg?svg.getBoundingClientRect().width:m.getBoundingClientRect().width;
    if(fw>w+1){m.classList.add('wide');}
  });
  var h=Math.ceil(c.getBoundingClientRect().bottom+6);
  if(window.PrepzoHeight){PrepzoHeight.postMessage(String(h));}
}
function prepzoReady(){ prepzoH(); if(window.PrepzoReady){PrepzoReady.postMessage('1');} }
window.MathJax={
  tex:{inlineMath:[['\$','\$'],['\\\\(','\\\\)']],displayMath:[['\$\$','\$\$'],['\\\\[','\\\\]']],processEscapes:true},
  svg:{fontCache:'global'},
  options:{enableMenu:false},
  startup:{pageReady:function(){
    return MathJax.startup.defaultPageReady().then(prepzoReady,prepzoReady);
  }}
};
</script>
<script async src="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-mml-svg.js" onerror="prepzoReady()"></script>
<style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent;}
html,body{margin:0;padding:0;background:transparent;}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  font-size:${size}px;color:$hex;line-height:1.5;overflow-x:hidden;}
#c{padding:2px 0;width:100%;overflow-wrap:anywhere;word-wrap:break-word;white-space:normal;}
p{margin:4px 0;} ul,ol{padding-left:20px;margin:4px 0;}
table{border-collapse:collapse;margin:8px 0;display:block;max-width:100%;overflow-x:auto;}
th,td{border:1px solid #cbd5e1;padding:6px 8px;text-align:left;vertical-align:top;font-size:${size - 1}px;}
th{background:#f1f5f9;font-weight:600;}
img{max-width:100%;height:auto;display:block;margin:8px 0;border-radius:8px;}
mjx-container{max-width:100%;}
mjx-container.wide{display:block!important;overflow-x:auto;overflow-y:hidden;padding:2px 0;}
.fit mjx-container.wide{overflow:hidden;}
.fit mjx-container.wide svg{max-width:100%;height:auto;}
.vec{position:relative;display:inline-block;}
.vec::before{content:"\\2192";position:absolute;left:50%;transform:translateX(-50%);top:-0.62em;font-size:0.72em;line-height:1;}
</style>
</head>
<body class="$fit">
<div id="c">$content</div>
<script>
(function(){
  document.querySelectorAll('img').forEach(function(i){
    i.addEventListener('load',prepzoH); i.addEventListener('error',function(){i.style.display='none';prepzoH();});
  });
  document.addEventListener('click',function(e){
    var t=e.target; if(t&&t.tagName==='IMG'&&window.PrepzoImage){PrepzoImage.postMessage(t.currentSrc||t.src);}
  });
  if(window.ResizeObserver){new ResizeObserver(prepzoH).observe(document.getElementById('c'));}
  window.addEventListener('load',prepzoH);
  prepzoH();
  if(!/[\\\\\$]|<math/i.test(document.getElementById('c').innerHTML)){prepzoReady();}
})();
</script>
</body>
</html>
''';
  }

  Widget _webView() {
    // Sideways drags go to the page so a wide equation can be scrolled;
    // vertical drags still scroll the screen.
    final recognizers = widget.interactive
        ? <Factory<OneSequenceGestureRecognizer>>{
            Factory<HorizontalDragGestureRecognizer>(
              HorizontalDragGestureRecognizer.new,
            ),
          }
        : const <Factory<OneSequenceGestureRecognizer>>{};
    final platform = _controller!.platform;
    if (platform is AndroidWebViewController) {
      // Hybrid composition: the default texture mode left some question
      // boxes black or blank on a real phone (Realme, Android 11) although
      // the page inside had rendered.
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: platform,
          displayWithHybridComposition: true,
          gestureRecognizers: recognizers,
        ),
      );
    }
    return WebViewWidget(
      controller: _controller!,
      gestureRecognizers: recognizers,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesWebView) {
      return Text(
        _prepared,
        style: TextStyle(
          fontSize: widget.baseFontSize,
          height: 1.5,
          color: widget.fontColor,
        ),
      );
    }
    final estimated = widget.baseFontSize * 1.5 + 8;
    final view = SizedBox(
      height: _contentHeight ?? estimated,
      child: Stack(
        children: [
          // No Opacity/AnimatedOpacity around the WebView: on some Android
          // phones (seen on a Realme, Android 11) a platform view under an
          // opacity layer paints black or stays blank.
          Positioned.fill(child: _webView()),
          if (!_ready)
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
    return widget.interactive ? view : IgnorePointer(child: view);
  }
}

/// Opens a picture full screen; pinch to zoom.
Future<void> showZoomableImage(BuildContext context, String src) {
  if (src.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.network(
                  src,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'Could not load the picture.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A question picture given as a separate URL field (not inside the HTML):
/// full width, tap to zoom, and a visible note if it fails to load.
class QuestionImage extends StatelessWidget {
  const QuestionImage({super.key, required this.url, this.maxHeight = 260});
  final String url;
  final double maxHeight;

  static String resolve(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('//')) return 'https:$u';
    final base = AppConfig.webUrl.replaceFirst(RegExp(r'/+$'), '');
    return u.startsWith('/') ? '$base$u' : '$base/$u';
  }

  @override
  Widget build(BuildContext context) {
    final src = resolve(url);
    return GestureDetector(
      onTap: () => showZoomableImage(context, src),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Image.network(
            src,
            width: double.infinity,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, __, ___) => Container(
              height: 56,
              alignment: Alignment.center,
              color: Colors.grey.shade100,
              child: Text(
                'Picture could not load. Check your internet.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
