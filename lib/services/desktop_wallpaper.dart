import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_tools;

class DesktopWallpaper {
  static const _channel = MethodChannel('app.wallfree/desktop');

  static Future<void> apply(String path) async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      throw UnsupportedError(
        'Wallpaper apply is available on macOS and Windows.',
      );
    }
    final platformPath = defaultTargetPlatform == TargetPlatform.windows
        ? await _windowsBitmapPath(path)
        : path;
    await _channel.invokeMethod<void>('applyWallpaper', platformPath);
  }

  static Future<String> _windowsBitmapPath(String sourcePath) async {
    final source = File(sourcePath);
    final sourceName = source.uri.pathSegments.last;
    final baseName = sourceName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final targetPath =
        '${source.parent.path}${Platform.pathSeparator}$baseName.windows.bmp';
    final target = File(targetPath);
    if (await target.exists()) return target.path;

    final decoded = image_tools.decodeImage(await source.readAsBytes());
    if (decoded == null) {
      throw const FormatException(
        'This file could not be decoded as an image.',
      );
    }
    await target.writeAsBytes(image_tools.encodeBmp(decoded), flush: true);
    return target.path;
  }
}
