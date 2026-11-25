import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/core/services/file_export_service.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/extras/data/models/extras_models.dart';
import 'package:lms/features/extras/presentation/cubit/extras_cubit.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// "Download receipt" button shown on a successful transaction card.
/// Downloads the server-generated PDF, saves it to Downloads and offers to
/// open or share it.
class ReceiptDownloadButton extends StatefulWidget {
  const ReceiptDownloadButton({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  State<ReceiptDownloadButton> createState() => _ReceiptDownloadButtonState();
}

class _ReceiptDownloadButtonState extends State<ReceiptDownloadButton> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    final txn = widget.transaction;
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final cubit = context.read<ExtrasCubit>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await cubit.downloadReceipt(token, txn.id);
      if (!mounted) return;
      if (!FileExportService.isSupported) {
        _openInApp(bytes);
        return;
      }
      final saved = await FileExportService.saveToDownloads(
        bytes,
        fileName: txn.receiptFileName,
      );
      if (!mounted) return;
      _showSavedSheet(saved, bytes);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(receiptErrorMessage(e)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openInApp(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ReceiptViewerScreen(bytes: bytes),
      ),
    );
  }

  void _showSavedSheet(SavedFile saved, Uint8List bytes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: AppTheme.success,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Receipt saved',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  saved.displayPath,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          try {
                            await FileExportService.share(
                              saved,
                              subject: 'Prepzo payment receipt',
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : AppTheme.primary,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : AppTheme.primary.withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final opened = await FileExportService.open(saved);
                          if (!opened && mounted) _openInApp(bytes);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Open'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _busy ? null : _download,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.secondary,
                ),
              )
            : const Icon(
                Icons.download_rounded,
                size: 18,
                color: AppTheme.secondary,
              ),
        label: Text(
          _busy ? 'Preparing receipt…' : 'Download receipt',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.primary,
          disabledBackgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppTheme.primary.withValues(alpha: 0.75),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.45)),
          ),
        ),
      ),
    );
  }
}

class _ReceiptViewerScreen extends StatelessWidget {
  const _ReceiptViewerScreen({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Receipt')),
      body: SfPdfViewer.memory(bytes, canShowScrollHead: false),
    );
  }
}

/// Short, student-friendly text for a failed receipt download.
String receiptErrorMessage(Object error) {
  if (error is FileExportException) return error.message;
  if (error is ApiException) {
    switch (error.statusCode) {
      case 403:
        return 'This receipt belongs to another account.';
      case 404:
        return 'Receipt is not available yet. Please try again later.';
      case 409:
        return 'Receipts are available only for successful payments.';
    }
    if (error.statusCode == null && error.message.length < 90) {
      return error.message;
    }
  }
  return 'Could not download the receipt. Please try again.';
}
