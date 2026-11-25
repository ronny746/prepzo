import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tells the app whether the phone was ringing or on a call (normal or VoIP).
///
/// Backed by native code in `MainActivity.kt` (AudioManager mode) and
/// `AppDelegate.swift` (CXCallObserver). Neither needs a runtime permission.
class CallStateService {
  CallStateService._();

  static const MethodChannel _channel = MethodChannel('prepzo/call_state');

  /// True if a call is going on now, or one rang/started/ended after [since].
  /// Returns false when the platform cannot tell (never throws).
  static Future<bool> wasInCallSince(DateTime since) async {
    try {
      final result = await _channel.invokeMethod<bool>('wasInCallSince', {
        'sinceMillis': since.millisecondsSinceEpoch,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('CallStateService unavailable: $e');
      return false;
    }
  }
}
