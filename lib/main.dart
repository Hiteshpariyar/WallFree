import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/wallpaper.dart';
import 'services/desktop_wallpaper.dart';
import 'services/library_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WallfreeApp());
}

class WallfreeApp extends StatelessWidget {
  const WallfreeApp({super.key});

  static const _canvas = Color(0xFF0D0F12);
  static const _panel = Color(0xFF14171B);
  static const _line = Color(0xFF252A30);
  static const _accent = Color(0xFFC5F36B);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wallfree',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _canvas,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: Color(0xFFB8D68B),
        surface: _panel,
        outline: _line,
      ),
      fontFamily: 'Arial',
      useMaterial3: true,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF252A30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: const LibraryHome(),
  );
}

enum _Section { library, favorites, settings }

class LibraryHome extends StatefulWidget {
  const LibraryHome({super.key});

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  final _store = LibraryStore();
  List<Wallpaper> _wallpapers = [];
  String? _selectedId;
  String? _activeId;
  bool _loading = true;
  bool _working = false;
  _Section _section = _Section.library;

  Wallpaper? get _selected {
    final candidates = _section == _Section.favorites
        ? _wallpapers.where((item) => item.isFavorite).toList()
        : _wallpapers;
    for (final item in candidates) {
      if (item.id == _selectedId) return item;
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  List<Wallpaper> get _visibleWallpapers => _section == _Section.favorites
      ? _wallpapers.where((item) => item.isFavorite).toList()
      : _wallpapers;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final items = await _store.load();
      final activeId = await _store.activeWallpaperId();
      if (!mounted) return;
      setState(() {
        _wallpapers = items;
        _activeId = activeId;
        _selectedId = activeId ?? (items.isEmpty ? null : items.first.id);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not open your library: $error');
    }
  }

  Future<void> _importWallpaper() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [LibraryStore.imageTypes],
        confirmButtonText: 'Add to library',
      );
      if (file == null) return;
      setState(() => _working = true);
      final wallpaper = await _store.importFile(file);
      final items = await _store.load();
      if (!mounted) return;
      setState(() {
        _wallpapers = items;
        _selectedId = wallpaper.id;
        _section = _Section.library;
        _working = false;
      });
      _showMessage('Added to your library. The original file stays untouched.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _showMessage('Could not import that image: $error');
    }
  }

  Future<void> _applyWallpaper(Wallpaper wallpaper) async {
    setState(() => _working = true);
    try {
      await DesktopWallpaper.apply(wallpaper.path);
      await _store.setActiveWallpaper(wallpaper.id);
      if (!mounted) return;
      setState(() {
        _activeId = wallpaper.id;
        _selectedId = wallpaper.id;
        _working = false;
      });
      _showMessage('Wallpaper applied to your desktop.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _showMessage(
        error.message ?? 'The operating system could not apply this image.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _showMessage('Could not apply wallpaper: $error');
    }
  }

  Future<void> _toggleFavorite(Wallpaper wallpaper) async {
    await _store.toggleFavorite(wallpaper);
    final items = await _store.load();
    if (!mounted) return;
    setState(() => _wallpapers = items);
  }

  Future<void> _removeWallpaper(Wallpaper wallpaper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text(
          '“${wallpaper.title}” will be deleted from Wallfree’s local library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _store.delete(wallpaper);
    final items = await _store.load();
    if (!mounted) return;
    setState(() {
      _wallpapers = items;
      if (_selectedId == wallpaper.id) {
        _selectedId = items.isEmpty ? null : items.first.id;
      }
      if (_activeId == wallpaper.id) _activeId = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1050;
            return Row(
              children: [
                _Sidebar(
                  compact: compact,
                  section: _section,
                  onSectionChanged: (section) =>
                      setState(() => _section = section),
                  onImport: _importWallpaper,
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _section == _Section.settings
                      ? _SettingsPage(store: _store)
                      : _LibraryPage(
                          section: _section,
                          wallpapers: _visibleWallpapers,
                          selected: _selected,
                          activeId: _activeId,
                          working: _working,
                          onImport: _importWallpaper,
                          onSelect: (wallpaper) =>
                              setState(() => _selectedId = wallpaper.id),
                          onApply: _applyWallpaper,
                          onFavorite: _toggleFavorite,
                          onDelete: _removeWallpaper,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.section,
    required this.onSectionChanged,
    required this.onImport,
  });

  final bool compact;
  final _Section section;
  final ValueChanged<_Section> onSectionChanged;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 82.0 : 236.0;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF111317),
        border: Border(right: BorderSide(color: Color(0xFF24282E))),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 22,
        ),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5F36B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wallpaper_rounded,
                    color: Color(0xFF18200C),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 11),
                  const Text(
                    'wallfree',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 44),
            if (!compact)
              const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 10),
                child: Text(
                  'LIBRARY',
                  style: TextStyle(
                    color: Color(0xFF7B838E),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            _NavButton(
              compact: compact,
              selected: section == _Section.library,
              icon: Icons.grid_view_rounded,
              label: 'All wallpapers',
              onTap: () => onSectionChanged(_Section.library),
            ),
            _NavButton(
              compact: compact,
              selected: section == _Section.favorites,
              icon: Icons.favorite_border_rounded,
              label: 'Favorites',
              onTap: () => onSectionChanged(_Section.favorites),
            ),
            const Spacer(),
            if (compact)
              IconButton.filled(
                tooltip: 'Add wallpaper',
                onPressed: onImport,
                icon: const Icon(Icons.add_rounded),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add wallpaper'),
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF18200C),
                    backgroundColor: const Color(0xFFC5F36B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _NavButton(
              compact: compact,
              selected: section == _Section.settings,
              icon: Icons.tune_rounded,
              label: 'Settings',
              onTap: () => onSectionChanged(_Section.settings),
            ),
            if (!compact) ...[
              const SizedBox(height: 18),
              const Text(
                'LOCAL BY DESIGN',
                style: TextStyle(
                  color: Color(0xFF737B86),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your images stay on this device.',
                style: TextStyle(
                  color: Color(0xFF969EA8),
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.compact,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool compact;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFFC5F36B)
        : const Color(0xFFA5ADB7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Tooltip(
        message: compact ? label : '',
        child: Material(
          color: selected ? const Color(0xFF242A1D) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!compact) const SizedBox(width: 12),
                  Icon(icon, size: 19, color: foreground),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.section,
    required this.wallpapers,
    required this.selected,
    required this.activeId,
    required this.working,
    required this.onImport,
    required this.onSelect,
    required this.onApply,
    required this.onFavorite,
    required this.onDelete,
  });

  final _Section section;
  final List<Wallpaper> wallpapers;
  final Wallpaper? selected;
  final String? activeId;
  final bool working;
  final VoidCallback onImport;
  final ValueChanged<Wallpaper> onSelect;
  final ValueChanged<Wallpaper> onApply;
  final ValueChanged<Wallpaper> onFavorite;
  final ValueChanged<Wallpaper> onDelete;

  @override
  Widget build(BuildContext context) {
    final isFavorites = section == _Section.favorites;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(38, 30, 38, 14),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFavorites ? 'YOUR PICKS' : 'YOUR COLLECTION',
                        style: const TextStyle(
                          color: Color(0xFF9DA78A),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isFavorites ? 'Favorites' : 'Wallpapers',
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        isFavorites
                            ? 'The images you come back to.'
                            : '${wallpapers.length} ${wallpapers.length == 1 ? 'image' : 'images'} saved on this device',
                        style: const TextStyle(
                          color: Color(0xFF98A0AA),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Import image'),
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF18200C),
                    backgroundColor: const Color(0xFFC5F36B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(38, 16, 38, 22),
            sliver: SliverToBoxAdapter(
              child: _FeaturedWallpaper(
                wallpaper: selected!,
                isActive: selected!.id == activeId,
                working: working,
                onApply: () => onApply(selected!),
              ),
            ),
          ),
        if (wallpapers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(favorites: isFavorites, onImport: onImport),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(38, 8, 38, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    isFavorites ? 'SAVED FAVORITES' : 'IN YOUR LIBRARY',
                    style: const TextStyle(
                      color: Color(0xFF818A95),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Color(0xFF79828D),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Stored locally',
                    style: TextStyle(color: Color(0xFF79828D), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(38, 0, 38, 36),
            sliver: SliverGrid.builder(
              itemCount: wallpapers.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 290,
                mainAxisExtent: 225,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final wallpaper = wallpapers[index];
                return _WallpaperCard(
                  wallpaper: wallpaper,
                  selected: selected?.id == wallpaper.id,
                  active: activeId == wallpaper.id,
                  onTap: () => onSelect(wallpaper),
                  onFavorite: () => onFavorite(wallpaper),
                  onDelete: () => onDelete(wallpaper),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedWallpaper extends StatelessWidget {
  const _FeaturedWallpaper({
    required this.wallpaper,
    required this.isActive,
    required this.working,
    required this.onApply,
  });

  final Wallpaper wallpaper;
  final bool isActive;
  final bool working;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1000;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171B),
        border: Border.all(color: const Color(0xFF292E35)),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewImage(path: wallpaper.path, height: 230),
                _FeaturedDetails(
                  wallpaper: wallpaper,
                  isActive: isActive,
                  working: working,
                  onApply: onApply,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _PreviewImage(path: wallpaper.path, height: 290),
                ),
                Expanded(
                  flex: 4,
                  child: _FeaturedDetails(
                    wallpaper: wallpaper,
                    isActive: isActive,
                    working: working,
                    onApply: onApply,
                  ),
                ),
              ],
            ),
    );
  }
}

class _FeaturedDetails extends StatelessWidget {
  const _FeaturedDetails({
    required this.wallpaper,
    required this.isActive,
    required this.working,
    required this.onApply,
  });

  final Wallpaper wallpaper;
  final bool isActive;
  final bool working;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(
                Icons.desktop_mac_rounded,
                color: Color(0xFFC5F36B),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'ON YOUR DESKTOP' : 'READY TO APPLY',
                style: const TextStyle(
                  color: Color(0xFFC5F36B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            wallpaper.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Added ${_dateLabel(wallpaper.addedAt)}  ·  Local image',
            style: const TextStyle(color: Color(0xFF9AA2AD), fontSize: 12),
          ),
          const SizedBox(height: 21),
          FilledButton.icon(
            onPressed: working || isActive ? null : onApply,
            icon: working
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isActive ? Icons.check_rounded : Icons.wallpaper_rounded,
                    size: 17,
                  ),
            label: Text(
              working
                  ? 'Applying…'
                  : isActive
                  ? 'Applied'
                  : 'Set as wallpaper',
            ),
            style: FilledButton.styleFrom(
              foregroundColor: const Color(0xFF18200C),
              backgroundColor: const Color(0xFFC5F36B),
              disabledBackgroundColor: const Color(0xFF4B5639),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Applies to your connected desktop displays.',
            style: TextStyle(color: Color(0xFF818A95), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.path, required this.height});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
    ),
  );
}

class _WallpaperCard extends StatelessWidget {
  const _WallpaperCard({
    required this.wallpaper,
    required this.selected,
    required this.active,
    required this.onTap,
    required this.onFavorite,
    required this.onDelete,
  });

  final Wallpaper wallpaper;
  final bool selected;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF14171B),
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFFC5F36B) : const Color(0xFF292E35),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(wallpaper.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _ImagePlaceholder(),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 82,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB8000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        _RoundAction(
                          icon: wallpaper.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: wallpaper.isFavorite
                              ? const Color(0xFFFF8496)
                              : Colors.white,
                          tooltip: wallpaper.isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onTap: onFavorite,
                        ),
                        const SizedBox(width: 7),
                        _CardMenu(onDelete: onDelete),
                      ],
                    ),
                  ),
                  if (active)
                    const Positioned(
                      left: 10,
                      top: 10,
                      child: _StatusPill(label: 'ON DESKTOP'),
                    ),
                  Positioned(
                    left: 14,
                    right: 12,
                    bottom: 13,
                    child: Text(
                      wallpaper.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF9099A4),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _dateLabel(wallpaper.addedAt),
                      style: const TextStyle(
                        color: Color(0xFF929AA4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFC5F36B),
                      size: 16,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More actions',
    onSelected: (value) {
      if (value == 'remove') onDelete();
    },
    color: const Color(0xFF20242A),
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'remove', child: Text('Remove from library')),
    ],
    child: const _RoundActionSurface(icon: Icons.more_horiz_rounded),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: _RoundActionSurface(icon: icon, color: color),
    ),
  );
}

class _RoundActionSurface extends StatelessWidget {
  const _RoundActionSurface({required this.icon, this.color = Colors.white});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: const Color(0x990B0D0F),
      borderRadius: BorderRadius.circular(40),
    ),
    child: Icon(icon, color: color, size: 17),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFC5F36B),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF18200C),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.favorites, required this.onImport});

  final bool favorites;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2115),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF333D29)),
            ),
            child: Icon(
              favorites
                  ? Icons.favorite_border_rounded
                  : Icons.add_photo_alternate_outlined,
              color: const Color(0xFFC5F36B),
              size: 32,
            ),
          ),
          const SizedBox(height: 19),
          Text(
            favorites ? 'No favorites yet' : 'A calmer desktop starts here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            favorites ? 'Tap the heart on any image to save it here.' : 'Bring in an image you love. Wallfree keeps a copy in your local library.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF929BA6),
              height: 1.5,
              fontSize: 13,
            ),
          ),
          if (!favorites) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Import your first image'),
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFF18200C),
                backgroundColor: const Color(0xFFC5F36B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF384437), Color(0xFF1A2630), Color(0xFF252537)],
      ),
    ),
    child: const Center(
      child: Icon(Icons.landscape_rounded, color: Color(0x99C5F36B), size: 42),
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.store});

  final LibraryStore store;

  @override
  Widget build(BuildContext context) => FutureBuilder<Directory>(
    future: store.libraryDirectory,
    builder: (context, snapshot) {
      final location = snapshot.data?.path ?? 'Loading…';
      return ListView(
        padding: const EdgeInsets.fromLTRB(38, 34, 38, 38),
        children: [
          const Text(
            'PREFERENCES',
            style: TextStyle(
              color: Color(0xFF9DA78A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A small, private home for your desktop images.',
            style: TextStyle(color: Color(0xFF98A0AA), fontSize: 13),
          ),
          const SizedBox(height: 27),
          _SettingCard(
            icon: Icons.folder_outlined,
            title: 'Local library',
            description: 'Imported images are copied here. Your original files are never changed.',
            detail: location,
          ),
          const SizedBox(height: 13),
          const _SettingCard(
            icon: Icons.cloud_off_outlined,
            title: 'Private and offline',
            description: 'Wallfree has no account, ads, subscription, telemetry, or online catalog in this first version.',
            detail: 'No network connection required',
          ),
          const SizedBox(height: 13),
          const _SettingCard(
            icon: Icons.desktop_windows_outlined,
            title: 'Static wallpapers',
            description: 'Apply one image across the connected desktop displays. Live video and per-display controls are not in this first version.',
            detail: 'macOS and Windows',
          ),
        ],
      );
    },
  );
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String description;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: const Color(0xFF14171B),
      border: Border.all(color: const Color(0xFF292E35)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF22291B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFC5F36B), size: 19),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF9AA2AD),
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                detail,
                style: const TextStyle(color: Color(0xFF7F8994), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
