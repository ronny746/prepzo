import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lms/core/config/app_config.dart';

class MathHtmlRenderer extends StatefulWidget {
  final String htmlContent;
  final double baseFontSize;
  final Color fontColor;

  const MathHtmlRenderer({
    super.key,
    required this.htmlContent,
    this.baseFontSize = 16.0,
    this.fontColor = Colors.black87,
  });

  @override
  State<MathHtmlRenderer> createState() => _MathHtmlRendererState();
}

class _MathHtmlRendererState extends State<MathHtmlRenderer> {
  late final WebViewController _controller;
  double _contentHeight = 44.0;
  bool _isLoading = true;
  late final bool _usesWebView;

  bool _requiresWebView(String content) {
    if (content.contains('<') && content.contains('>')) return true;
    if (content.contains('\\') || content.contains('\$')) return true;
    return RegExp(
      r'<(?:img|math|table|tr|td|th|p|div|ul|ol|li|sub|sup|b|i|strong|em|span)\b|\\\\\(|\$[^$]+\$|\\\[',
      caseSensitive: false,
    ).hasMatch(content);
  }

  String _plainText(String content) => content
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .trim();

  @override
  void initState() {
    super.initState();
    _usesWebView = _requiresWebView(widget.htmlContent);
    if (!_usesWebView) {
      _isLoading = false;
      return;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            Future.delayed(const Duration(milliseconds: 250), () async {
              if (!mounted) return;
              try {
                final heightStr = await _controller.runJavaScriptReturningResult(
                  "document.body.scrollHeight;"
                );
                final height = double.tryParse(heightStr.toString());
                if (height != null && height > 0) {
                  setState(() {
                    _contentHeight = height + 12;
                    _isLoading = false;
                  });
                } else {
                  setState(() => _isLoading = false);
                }
              } catch (e) {
                setState(() => _isLoading = false);
              }
            });
          },
        ),
      )
      ..loadHtmlString(_buildHtml(widget.htmlContent));
  }

  @override
  void didUpdateWidget(MathHtmlRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_usesWebView && oldWidget.htmlContent != widget.htmlContent) {
      _controller.loadHtmlString(_buildHtml(widget.htmlContent));
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
  }

  String _buildHtml(String content) {
    final hexColor = _colorToHex(widget.fontColor);
    final String domain = AppConfig.webUrl;
    var processed = content.replaceAll('src="/', 'src="$domain/');

    // Auto-wrap unwrapped LaTeX math expressions (like \frac{a}{b}, \sqrt{x}, \vec{A})
    if (processed.contains('\\') &&
        !processed.contains('\\(') &&
        !processed.contains('\$')) {
      processed = '\\($processed\\)';
    }

    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <script>
        MathJax = {
          startup: {
            pageReady: () => {
              return MathJax.startup.defaultPageReady();
            }
          },
          tex: {
            inlineMath: [['\$', '\$'], ['\\\\(', '\\\\)']],
            displayMath: [['\$\$', '\$\$'], ['\\\\[', '\\\\]']]
          },
          svg: {
            fontCache: 'global'
          }
        };
      </script>
      <script type="text/javascript" id="MathJax-script" async
        src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/mml-chtml.js">
      </script>
      <style>
        * {
          box-sizing: border-box;
        }
        /* Wide content (long equations) scrolls sideways instead of being
           clipped; normal text still wraps because the body width is fixed. */
        html, body {
          overflow-x: auto;
          overflow-y: hidden;
        }
        mjx-container[display="true"] {
          overflow-x: auto;
          overflow-y: hidden;
          max-width: 100%;
        }
        body { 
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          font-size: ${widget.baseFontSize}px; 
          color: $hexColor;
          margin: 0; 
          padding: 4px 0px; 
          background-color: transparent;
          line-height: 1.5;
          word-wrap: break-word;
          overflow-wrap: break-word;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          margin: 8px 0;
        }
        th, td {
          border: 1px solid #cbd5e1;
          padding: 8px 10px;
          text-align: left;
          vertical-align: top;
          font-size: ${widget.baseFontSize - 1}px;
        }
        th {
          background-color: #f1f5f9;
          font-weight: 600;
        }
        img {
          max-width: 100%;
          max-height: 250px;
          object-fit: contain;
          height: auto;
          display: block;
          margin: 8px 0;
          border-radius: 8px;
        }
        p {
          margin: 4px 0;
        }
        ul, ol {
          padding-left: 20px;
          margin: 4px 0;
        }
      </style>
    </head>
    <body>
      $processed
    </body>
    </html>
    """;
  }

  @override
  Widget build(BuildContext context) {
    if (!_usesWebView) {
      return Text(
        _plainText(widget.htmlContent),
        style: TextStyle(
          fontSize: widget.baseFontSize,
          height: 1.5,
          color: widget.fontColor,
        ),
      );
    }
    return SizedBox(
      height: _contentHeight,
      child: Stack(
        children: [
          // Claim horizontal drags so wide equations can be scrolled; vertical
          // drags still go to the surrounding page scroll view.
          WebViewWidget(
            controller: _controller,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<HorizontalDragGestureRecognizer>(
                () => HorizontalDragGestureRecognizer(),
              ),
            },
          ),
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
