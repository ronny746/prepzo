import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// A file saved where the student can find it again.
class SavedFile {
  const SavedFile({required this.uri, required this.displayPath});

  /// content:// uri on Android (usable for open / share).
  final String uri;

  /// Human readable location, e.g. "Downloads/Prepzo-Receipt-123.pdf".
  final String displayPath;
}

/// Saves generated files (PDF receipts) to the phone's Downloads folder and
/// opens / shares them with other apps. Android only; backed by the
/// `prepzo/files` channel in MainActivity (MediaStore on Android 10+, so no
/// storage permission is needed there).
class FileExportService {
  FileExportService._();

  static const MethodChannel _channel = MethodChannel('prepzo/files');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<SavedFile> saveToDownloads(
    Uint8List bytes, {
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    if (!isSupported) {
      throw const FileExportException(
        'Saving files is supported on Android only.',
      );
    }
    final sdk = await _channel.invokeMethod<int>('sdkInt') ?? 0;
    if (sdk < 29) {
      // Android 8-9 write straight to the public Downloads folder.
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw const FileExportException(
          'Storage permission is needed to save the receipt to Downloads.',
        );
      }
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'saveToDownloads',
        {'bytes': bytes, 'fileName': fileName, 'mimeType': mimeType},
      );
      final uri = result?['uri']?.toString() ?? '';
      if (uri.isEmpty) {
        throw const FileExportException('Could not save the file.');
      }
      return SavedFile(
        uri: uri,
        displayPath:
            result?['displayPath']?.toString() ?? 'Downloads/$fileName',
      );
    } on PlatformException catch (e) {
      throw FileExportException(e.message ?? 'Could not save the file.');
    }
  }

  /// Opens the file in a PDF viewer. Returns false when no app can open it.
  static Future<bool> open(
    SavedFile file, {
    String mimeType = 'application/pdf',
  }) async {
    try {
      return await _channel.invokeMethod<bool>('openFile', {
            'uri': file.uri,
            'mimeType': mimeType,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> share(
    SavedFile file, {
    String mimeType = 'application/pdf',
    String? subject,
  }) async {
    try {
      await _channel.invokeMethod<void>('shareFile', {
        'uri': file.uri,
        'mimeType': mimeType,
        'subject': subject ?? '',
      });
    } on PlatformException catch (e) {
      throw FileExportException(e.message ?? 'Could not share the file.');
    }
  }
}

class FileExportException implements Exception {
  const FileExportException(this.message);
  final String message;

  @override
  String toString() => message;
}
