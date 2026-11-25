import 'dart:io';
import 'package:flutter/foundation.dart';

enum Environment { dev, prod }

class AppConfig {
  static const Environment currentEnvironment = Environment.prod;

  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.dev:
        if (kIsWeb) return 'http://localhost:1220/api/v1';
        if (Platform.isAndroid)
          return 'http://10.0.2.2:1220/api/v1'; // Local IP for physical Android device or emulator
        return 'http://localhost:1220/api/v1';
      case Environment.prod:
        return 'https://theprepzo.com/api/v1';
    }
  }

  static String get webUrl {
    final base = baseUrl;
    if (base.endsWith('/api/v1')) {
      return base.substring(0, base.length - '/api/v1'.length);
    }
    return base;
  }
}
