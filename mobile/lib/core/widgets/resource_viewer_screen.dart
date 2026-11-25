import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:lms/core/theme/app_theme.dart';

class ResourceViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String type; // e.g. "VIDEO", "NOTES", "PAST_PAPER", "DOCUMENT", "PDF"

  const ResourceViewerScreen({
    super.key,
    required this.url,
    required this.title,
    required this.type,
  });

  @override
  State<ResourceViewerScreen> createState() => _ResourceViewerScreenState();
}

enum _ViewerMode { pdf, video, image, webView }

class _ResourceViewerScreenState extends State<ResourceViewerScreen> {
  late _ViewerMode _mode;
  late final PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  WebViewController? _webViewController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool _isLoading = true;
  String? _pdfLoadError;
  bool _isVideoError = false;
  int _pageNumber = 1;
  int _pageCount = 0;

  late String _processedPdfUrl;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _processedPdfUrl = _getProcessedPdfUrl(widget.url);
    _determineModeAndInit();
  }

  String _getProcessedPdfUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;
    if (rawUrl.contains('drive.google.com')) {
      final match = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(rawUrl);
      if (match != null) {
        final fileId = match.group(1);
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
      final idParam = uri.queryParameters['id'];
      if (idParam != null && idParam.isNotEmpty) {
        return 'https://drive.google.com/uc?export=download&id=$idParam';
      }
    }
    return rawUrl;
  }

  void _fallbackToGoogleDocsViewer() {
    final docsViewerUrl =
        'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.url)}';
    if (mounted) {
      setState(() {
        _mode = _ViewerMode.webView;
        _isLoading = true;
        _pdfLoadError = null;
      });
      _initWebView(docsViewerUrl);
    }
  }

  void _determineModeAndInit() {
    final lowerUrl = widget.url.toLowerCase();
    final typeUpper = widget.type.toUpperCase();

    if (typeUpper == 'VIDEO' ||
        lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mkv') ||
        lowerUrl.endsWith('.mov') ||
        _isYoutube(widget.url)) {
      _mode = _ViewerMode.video;
      _initVideoPlayer();
    } else if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.gif')) {
      _mode = _ViewerMode.image;
      _isLoading = false;
    } else if (lowerUrl.endsWith('.doc') ||
        lowerUrl.endsWith('.docx') ||
        lowerUrl.endsWith('.ppt') ||
        lowerUrl.endsWith('.pptx')) {
      _fallbackToGoogleDocsViewer();
    } else {
      // Default documents & PDFs to native Syncfusion PDF Viewer
      _mode = _ViewerMode.pdf;
    }
  }

  bool _isYoutube(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String _getYoutubeEmbedUrl(String url) {
    final RegExp regex = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final videoId = match.group(1);
      return 'https://www.youtube.com/embed/$videoId?autoplay=1';
    }
    return url;
  }

  void _initWebView(String targetUrl) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  Future<void> _initVideoPlayer() async {
    if (_isYoutube(widget.url)) {
      _mode = _ViewerMode.webView;
      _initWebView(_getYoutubeEmbedUrl(widget.url));
      return;
    }

    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          );
        },
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVideoError = true;
        });
      }
    }
  }

  Future<void> _openInExternalApp() async {
    final uri = Uri.parse(widget.url);
    try {
      final launched = await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open external viewer.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showJumpToPageDialog() {
    if (_pageCount <= 1) return;
    final controller = TextEditingController(text: '$_pageNumber');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Go to Page',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter page number (1 to $_pageCount):',
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B)),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Page number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () {
              final target = int.tryParse(controller.text.trim());
              if (target != null && target >= 1 && target <= _pageCount) {
                _pdfViewerController.jumpToPage(target);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid page (1 - $_pageCount)'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.arrowLeftBold,
            size: 20.sp,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            if (_mode == _ViewerMode.pdf && _pageCount > 0)
              Text(
                'Page $_pageNumber of $_pageCount',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
          ],
        ),
        actions: [
          if (_mode == _ViewerMode.pdf && _pageCount > 1)
            IconButton(
              icon: PhosphorIcon(
                PhosphorIcons.listNumbersBold,
                size: 20.sp,
                color: const Color(0xFF0F172A),
              ),
              tooltip: 'Go to Page',
              onPressed: _showJumpToPageDialog,
            ),
          IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowSquareOutBold,
              size: 20.sp,
              color: AppTheme.primary,
            ),
            tooltip: 'Open in External App / Browser',
            onPressed: _openInExternalApp,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _ViewerMode.pdf:
        return _buildPdfViewer();
      case _ViewerMode.video:
        return _buildVideoPlayer();
      case _ViewerMode.image:
        return _buildImageViewer();
      case _ViewerMode.webView:
        return _buildWebView();
    }
  }

  // --- NATIVE PDF VIEWER ---
  Widget _buildPdfViewer() {
    if (_pdfLoadError != null) {
      return _buildPdfErrorState();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SfPdfViewer.network(
          _processedPdfUrl,
          key: _pdfViewerKey,
          controller: _pdfViewerController,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          canShowPaginationDialog: true,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _pageCount = details.document.pages.count;
              });
            }
          },
          onPageChanged: (PdfPageChangedDetails details) {
            if (mounted) {
              setState(() {
                _pageNumber = details.newPageNumber;
              });
            }
          },
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            debugPrint('SfPdfViewer load failed: ${details.description}, fallback to WebViewer');
            if (mounted) {
              _fallbackToGoogleDocsViewer();
            }
          },
        ),

        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.white.withValues(alpha: 0.8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 12.h),
                  Text(
                    'Loading document...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Floating Page Pill
        if (_pageCount > 1 && !_isLoading)
          Positioned(
            bottom: 16.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Text(
                '$_pageNumber / $_pageCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.filePdfBold,
              size: 48.sp,
              color: AppTheme.error,
            ),
            SizedBox(height: 12.h),
            Text(
              'Could Not Render PDF',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _pdfLoadError ?? 'Unable to download or display this document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5.sp,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _pdfLoadError = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  icon: PhosphorIcon(
                    PhosphorIcons.arrowClockwiseBold,
                    size: 15.sp,
                  ),
                  label: const Text('Retry'),
                ),
                SizedBox(width: 10.w),
                ElevatedButton.icon(
                  onPressed: _openInExternalApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  icon: PhosphorIcon(
                    PhosphorIcons.arrowSquareOutBold,
                    size: 15.sp,
                  ),
                  label: const Text('Open Externally'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- IMAGE VIEWER ---
  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.imageBrokenBold,
                    size: 40.sp,
                    color: AppTheme.error,
                  ),
                  SizedBox(height: 8.h),
                  const Text('Failed to load image'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- VIDEO PLAYER ---
  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_isVideoError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.videoCameraSlashBold,
              size: 40.sp,
              color: AppTheme.error,
            ),
            SizedBox(height: 8.h),
            const Text(
              'Failed to load video.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: _openInExternalApp,
              child: const Text('Open in Browser'),
            ),
          ],
        ),
      );
    }
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Center(child: Chewie(controller: _chewieController!));
    } else {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
  }

  // --- WEBVIEW ---
  Widget _buildWebView() {
    if (_webViewController == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ],
    );
  }
}
