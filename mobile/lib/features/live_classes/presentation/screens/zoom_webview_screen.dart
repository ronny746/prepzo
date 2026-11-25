import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:lms/core/config/app_config.dart';

class LiveClassWebViewScreen extends StatefulWidget {
  final String? meetingLink;
  final String? meetingId;
  final String? meetingPassword;
  final String? displayName;
  final String? token;

  const LiveClassWebViewScreen({
    super.key,
    this.meetingLink,
    this.meetingId,
    this.meetingPassword,
    this.displayName,
    this.token,
  });

  @override
  State<LiveClassWebViewScreen> createState() => _LiveClassWebViewScreenState();
}

typedef ZoomWebViewScreen = LiveClassWebViewScreen;

class _LiveClassWebViewScreenState extends State<LiveClassWebViewScreen> {
  late final WebViewController _controller;
  bool _isPermissionGranted = false;
  bool _isControllerInitialized = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted) {
      if (mounted) {
        setState(() {
          _isPermissionGranted = true;
        });
        _initController();
      }
    } else {
      if (mounted) {
        setState(() {
          _isPermissionGranted = true;
        });
        _initController();
      }
    }
  }

  String _resolveUrl(String link, String id, String token, String name) {
    if (link.isNotEmpty) {
      if (link.contains('youtube.com') ||
          link.contains('youtu.be') ||
          link.contains('vimeo.com') ||
          link.endsWith('.m3u8') ||
          link.endsWith('.mp4')) {
        return link;
      }

      if (link.startsWith('http://') || link.startsWith('https://')) {
        return _appendAuthParams(link, token, name);
      }

      if (link.startsWith('/')) {
        return _appendAuthParams('${AppConfig.webUrl}$link', token, name);
      }

      return _appendAuthParams('${AppConfig.webUrl}/class/$link', token, name);
    }

    if (id.isNotEmpty) {
      if (id.startsWith('http://') || id.startsWith('https://')) {
        return _appendAuthParams(id, token, name);
      }
      return _appendAuthParams('${AppConfig.webUrl}/class/$id', token, name);
    }

    return _appendAuthParams(
      '${AppConfig.webUrl}/student/live-classes',
      token,
      name,
    );
  }

  String _appendAuthParams(String urlStr, String token, String name) {
    try {
      final uri = Uri.parse(urlStr);
      final params = Map<String, String>.from(uri.queryParameters);
      if (token.isNotEmpty) params['token'] = token;
      if (name.isNotEmpty) params['name'] = name;
      params['role'] = 'student';
      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      return urlStr;
    }
  }

  void _injectAuthAndCleanUI(String token, String name) {
    final String jsCode =
        '''
      (function() {
        try {
          if ("$token".length > 0) {
            localStorage.setItem('token', "$token");
          }
          localStorage.setItem('user', JSON.stringify({
            "username": "$name",
            "name": "$name",
            "role": "student"
          }));
        } catch(e) {}

        if (!window.__flutterExitInjected) {
          window.__flutterExitInjected = true;

          const notifyLeave = function(reason) {
            console.log('[WebView JS] Triggering leave due to: ' + reason);
            try {
              if (window.FlutterNative && window.FlutterNative.postMessage) {
                window.FlutterNative.postMessage('leave');
              }
            } catch(e) {
              console.error('[WebView JS] Failed to postMessage: ' + e);
            }
          };

          const checkExit = function() {
            const href = window.location.href;
            if (href.includes('/student/live-classes') ||
                href.includes('/teacher/live-classes') ||
                href.includes('/admin/live-classes') ||
                href.includes('/dashboard') ||
                href.includes('leave') ||
                href.includes('postmeeting')) {
              notifyLeave('URL match (' + href + ')');
            }
          };

          const origPush = history.pushState;
          history.pushState = function() {
            const res = origPush.apply(this, arguments);
            checkExit();
            return res;
          };

          const origReplace = history.replaceState;
          history.replaceState = function() {
            const res = origReplace.apply(this, arguments);
            checkExit();
            return res;
          };

          window.addEventListener('popstate', checkExit);
          setInterval(checkExit, 200);
        }
      })();
    ''';
    _controller.runJavaScript(jsCode);
  }

  void _initController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (WebViewPermissionRequest request) {
        debugPrint("[WebView] Granting media permissions");
        request.grant();
      },
    );

    final String rawLink = widget.meetingLink ?? '';
    final String rawId = widget.meetingId ?? '';
    final String userToken = widget.token ?? '';
    final String userName =
        (widget.displayName != null && widget.displayName!.isNotEmpty)
        ? widget.displayName!
        : 'Student';

    final String targetUrl = _resolveUrl(rawLink, rawId, userToken, userName);
    debugPrint(
      "[WebView] Initializing LiveClassWebViewScreen with targetUrl: $targetUrl",
    );

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setUserAgent(
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint(
          "[WebView JS Console] ${message.level.name}: ${message.message}",
        );
      })
      ..addJavaScriptChannel(
        'FlutterNative',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint(
            '[WebView JS Channel] Message received: ${message.message}',
          );
          if (message.message == 'leave') {
            _closeAndExit();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[WebView] onPageStarted: $url');
            _injectAuthAndCleanUI(userToken, userName);
          },
          onPageFinished: (String url) {
            debugPrint('[WebView] onPageFinished: $url');
            _injectAuthAndCleanUI(userToken, userName);
            if (url.contains('leave') ||
                url.contains('postmeeting') ||
                url.contains('/student/live-classes') ||
                url.contains('/teacher/live-classes') ||
                url.contains('leave-class')) {
              debugPrint(
                '[WebView] onPageFinished detected leave URL -> popping screen',
              );
              _closeAndExit();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              "[WebView] WebResourceError code: ${error.errorCode}, description: ${error.description}, errorType: ${error.errorType}, isMainFrame: ${error.isForMainFrame}, url: ${error.url}",
            );
            if (error.isForMainFrame == true &&
                !(error.url?.contains('leave') ?? false)) {
              debugPrint(
                "[WebView] Main frame error detected -> popping screen",
              );
              _closeAndExit();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('[WebView] onNavigationRequest: $url');
            if (url.contains('leave') ||
                url.contains('postmeeting') ||
                url.contains('/student/live-classes') ||
                url.contains('/teacher/live-classes') ||
                url.contains('/admin/live-classes') ||
                url.contains('/dashboard') ||
                url.contains('leave-class') ||
                url.startsWith('about:blank')) {
              debugPrint(
                '[WebView] Intercepted exit navigation: $url -> popping screen',
              );
              _closeAndExit();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(Uri.parse(targetUrl));

    if (mounted) {
      setState(() {
        _isControllerInitialized = true;
      });
    }
  }

  void _closeAndExit() {
    if (!mounted || _isExiting) return;
    _isExiting = true;
    debugPrint("[WebView] Executing _closeAndExit()...");
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        debugPrint("[WebView] PopScope triggered");
        _closeAndExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Live Class',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          leading: BackButton(
            color: Colors.white,
            onPressed: () {
              debugPrint("[WebView] AppBar BackButton pressed");
              _closeAndExit();
            },
          ),
        ),
        body: (!_isPermissionGranted || !_isControllerInitialized)
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
