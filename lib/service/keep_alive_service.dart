import 'dart:io';
import 'package:flutter/services.dart';

class KeepAliveService {
  static const _channel = MethodChannel('com.ytmusix.app/keep_alive');

  static bool get isAndroidPlatform => Platform.isAndroid;

  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? true;
    } on PlatformException catch (_) {
      return true;
    }
  }

  static Future<void> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestDisableBatteryOptimization');
    } on PlatformException catch (_) {
      // ignore
    }
  }

  static Future<void> startKeepAliveService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startKeepAliveService');
    } on PlatformException catch (_) {
      // ignore
    }
  }

  static Future<void> stopKeepAliveService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopKeepAliveService');
    } on PlatformException catch (_) {
      // ignore
    }
  }

  static Future<bool> isKeepAliveServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isKeepAliveServiceRunning') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
