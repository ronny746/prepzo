import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PaymentWebViewScreen({
    super.key,
    required this.url,
    this.title = 'Payment',
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _launchedExternalApp = false;
  bool _isHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkRedirectStatus(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkRedirectStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description} (${error.errorCode})");
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            final lowerUrl = url.toLowerCase();

            // Handle UPI and deep links
            if (lowerUrl.startsWith('upi://') ||
                lowerUrl.startsWith('intent://') ||
                lowerUrl.startsWith('phonepe://') ||
                lowerUrl.startsWith('paytmmp://') ||
                lowerUrl.startsWith('paytm://') ||
                lowerUrl.startsWith('bhim://') ||
                lowerUrl.startsWith('tez://') ||
                lowerUrl.startsWith('gpay://')) {
              _launchDeepLink(url);
              return NavigationDecision.prevent;
            }

            // Check for payment status redirect URLs
            if (_checkRedirectStatus(url)) {
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launchedExternalApp) {
      _launchedExternalApp = false;
      // When returning from external UPI app (GPay/PhonePe/Paytm), reload WebView to get Easebuzz transaction status update
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (!mounted || _isHandled) return;
        try {
          final currentUrl = await _controller.currentUrl();
          if (currentUrl != null) {
            if (!_checkRedirectStatus(currentUrl)) {
              _controller.reload();
            }
          } else {
            _controller.reload();
          }
        } catch (e) {
          debugPrint("Error checking URL on resume: $e");
        }
      });
    }
  }

  bool _checkRedirectStatus(String url) {
    if (_isHandled) return true;

    final lowerUrl = url.toLowerCase();
    final uri = Uri.tryParse(url);
    final statusParam = uri?.queryParameters['status']?.toLowerCase();
    final resultParam = uri?.queryParameters['result']?.toLowerCase();

    // Check for success indicators
    bool isSuccess = statusParam == 'success' ||
        statusParam == 'successful' ||
        statusParam == 'userpaid' ||
        statusParam == 'user_paid' ||
        statusParam == 'captured' ||
        resultParam == 'success' ||
        lowerUrl.contains('status=success') ||
        lowerUrl.contains('status=successful') ||
        lowerUrl.contains('status=userpaid') ||
        lowerUrl.contains('status=user_paid') ||
        lowerUrl.contains('status=captured') ||
        lowerUrl.contains('payment-success') ||
        lowerUrl.contains('/payment/success') ||
        lowerUrl.contains('easebuzz_success');

    if (isSuccess) {
      _handlePaymentComplete(success: true);
      return true;
    }

    // Check for failure/cancel indicators
    bool isFailure = statusParam == 'failed' ||
        statusParam == 'failure' ||
        statusParam == 'usercancelled' ||
        statusParam == 'user_cancelled' ||
        statusParam == 'cancelled' ||
        statusParam == 'error' ||
        resultParam == 'failure' ||
        lowerUrl.contains('status=failed') ||
        lowerUrl.contains('status=failure') ||
        lowerUrl.contains('status=usercancelled') ||
        lowerUrl.contains('status=user_cancelled') ||
        lowerUrl.contains('status=error') ||
        lowerUrl.contains('payment-failure') ||
        lowerUrl.contains('/payment/failure') ||
        lowerUrl.contains('easebuzz_failure');

    if (isFailure) {
      _handlePaymentComplete(success: false);
      return true;
    }

    return false;
  }

  void _handlePaymentComplete({required bool success}) {
    if (!mounted || _isHandled) return;
    _isHandled = true;
    Navigator.of(context).pop(success);
  }

  Future<void> _launchDeepLink(String rawUrl) async {
    _launchedExternalApp = true;
    try {
      String launchableUrl = rawUrl;

      // Convert intent:// to upi:// for Android package resolution
      if (rawUrl.startsWith('intent://')) {
        final schemeMatch = RegExp(r'scheme=([^;]+)').firstMatch(rawUrl);
        final scheme = schemeMatch?.group(1) ?? 'upi';
        final mainPart = rawUrl.substring('intent://'.length).split('#Intent;')[0];
        launchableUrl = '$scheme://$mainPart';
      }

      final Uri uri = Uri.parse(launchableUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching deep link: $e");
      try {
        await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
        ],
      ),
    );
  }
}
