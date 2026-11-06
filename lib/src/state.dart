import 'package:flutter/services.dart';

/// Settings shared across the package.
class BopmigoState {
  static String? appId;
  static Uri host = Uri.parse('https://bopmigo.com');
  static bool hideAllText = false;
  static String? screen;
  static Map<String, String> user = {};
  static Map<String, String> custom = {};
  static Map<String, Object?> native = {};

  static const channel = MethodChannel('bopmigo');
}
