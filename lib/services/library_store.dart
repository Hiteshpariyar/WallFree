import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallpaper.dart';

class LibraryStore {
  LibraryStore() : _preferences = SharedPreferencesAsync();

  static const _wallpapersKey = 'wallfree.wallpapers.v1';
  static const _activeWallpaperKey = 'wallfree.activeWallpaper.v1';
  static const imageTypes = XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    uniformTypeIdentifiers: [
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
      'com.microsoft.bmp',
    ],
  );

  final SharedPreferencesAsync _preferences;
  Directory? _libraryDirectory;

  Future<Directory> get libraryDirectory async {
    final cached = _libraryDirectory;
    if (cached != null) return cached;

    final appSupport = await getApplicationSupportDirectory();
    final directory = Directory(
      '${appSupport.path}${Platform.pathSeparator}Wallfree${Platform.pathSeparator}wallpapers',
    );
    await directory.create(recursive: true);
    _libraryDirectory = directory;
    return directory;
  }

  Future<List<Wallpaper>> load() async {
    final raw = await _preferences.getString(_wallpapersKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<Object?>;
      final entries = <Wallpaper>[];
      for (final value in decoded) {
        if (value is! Map<String, Object?>) continue;
        final wallpaper = Wallpaper.fromJson(value);
        if (await File(wallpaper.path).exists()) entries.add(wallpaper);
      }
      return entries;
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<Wallpaper> importFile(XFile source) async {
    final directory = await libraryDirectory;
    final originalName = source.name.trim().isEmpty ? 'Wallpaper' : source.name;
    final dot = originalName.lastIndexOf('.');
    final extension = dot < 0 ? '' : originalName.substring(dot).toLowerCase();
    final baseName = dot < 0 ? originalName : originalName.substring(0, dot);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final safeBaseName = baseName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final target = File(
      '${directory.path}${Platform.pathSeparator}$id$extension',
    );
    await target.writeAsBytes(await source.readAsBytes(), flush: true);

    final wallpaper = Wallpaper(
      id: id,
      title: safeBaseName.isEmpty ? 'My wallpaper' : safeBaseName,
      path: target.path,
      addedAt: DateTime.now(),
    );
    final current = await load();
    await _save([wallpaper, ...current]);
    return wallpaper;
  }

  Future<void> toggleFavorite(Wallpaper wallpaper) async {
    final current = await load();
    await _save([
      for (final item in current)
        item.id == wallpaper.id
            ? item.copyWith(isFavorite: !item.isFavorite)
            : item,
    ]);
  }

  Future<void> delete(Wallpaper wallpaper) async {
    final file = File(wallpaper.path);
    if (await file.exists()) await file.delete();
    final imageName = file.uri.pathSegments.last;
    final baseName = imageName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final windowsBitmap = File(
      '${file.parent.path}${Platform.pathSeparator}$baseName.windows.bmp',
    );
    if (await windowsBitmap.exists()) await windowsBitmap.delete();
    final current = await load();
    await _save(current.where((item) => item.id != wallpaper.id).toList());
    if (await _preferences.getString(_activeWallpaperKey) == wallpaper.id) {
      await _preferences.remove(_activeWallpaperKey);
    }
  }

  Future<String?> activeWallpaperId() =>
      _preferences.getString(_activeWallpaperKey);

  Future<void> setActiveWallpaper(String id) =>
      _preferences.setString(_activeWallpaperKey, id);

  Future<void> _save(List<Wallpaper> wallpapers) => _preferences.setString(
    _wallpapersKey,
    jsonEncode(wallpapers.map((item) => item.toJson()).toList()),
  );
}
