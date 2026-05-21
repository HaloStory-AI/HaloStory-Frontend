import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/localization_service.dart';
import '../../services/theme_service.dart';
import '../../services/wallpaper_service.dart';
import '../splash_screen.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  String _currentLanguage = 'id';
  bool _isLanguageChanged = false;
  bool _amoledDarkEnabled = false;

  @override
  void initState() {
    super.initState();
    WallpaperService().addListener(_onWallpaperChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    WallpaperService().removeListener(_onWallpaperChanged);
    super.dispose();
  }

  void _onWallpaperChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _currentLanguage = LocalizationService().currentLocale;
      _amoledDarkEnabled = ThemeService().isAmoledDark;
    });
  }

  Future<void> _saveSettings() async {
    await ThemeService().setAmoledDark(_amoledDarkEnabled);

    if (!mounted) return;
    if (_isLanguageChanged) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_saved_success')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'wallpaper_${DateTime.now().millisecondsSinceEpoch}.png';
    final localPath = '${dir.path}/$fileName';
    await File(image.path).copy(localPath);
    await WallpaperService().setGallery(localPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardColor = isDark
        ? colorScheme.surface
        : colorScheme.surfaceContainer;
    final Color textColor = colorScheme.onSurface;
    final bool showWallpaper = WallpaperService.isMobileLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('settings_tab_appearance'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Section: Language ──
            Text(
              tr('settings_language'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _currentLanguage,
                  items: [
                    DropdownMenuItem(
                      value: 'id',
                      child: Text(tr('settings_language_id')),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(tr('settings_language_en')),
                    ),
                    DropdownMenuItem(
                      value: 'zh',
                      child: Text(tr('settings_language_zh')),
                    ),
                    DropdownMenuItem(
                      value: 'ja',
                      child: Text(tr('settings_language_ja')),
                    ),
                    DropdownMenuItem(
                      value: 'ko',
                      child: Text(tr('settings_language_ko')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _currentLanguage = v;
                        _isLanguageChanged = true;
                      });
                      LocalizationService().load(v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Section: Wallpaper ──
            if (showWallpaper) ...[
              Text(
                tr('settings_wallpaper'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: WallpaperService.presetWallpapers.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isActive = WallpaperService().type == 'none';
                      return GestureDetector(
                        onTap: () => WallpaperService().setNone(),
                        child: Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isActive
                                ? Border.all(color: colorScheme.primary, width: 2.5)
                                : Border.all(color: cardColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block, color: textColor.withValues(alpha: 0.5), size: 24),
                              const SizedBox(height: 4),
                              Text(
                                tr('settings_wallpaper_none'),
                                style: TextStyle(fontSize: 10, color: textColor),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final assetPath = WallpaperService.presetWallpapers[index - 1];
                    final isActive = WallpaperService().type == 'preset' &&
                        WallpaperService().value == assetPath;
                    return GestureDetector(
                      onTap: () => WallpaperService().setPreset(assetPath),
                      child: Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: isActive
                              ? Border.all(color: colorScheme.primary, width: 2.5)
                              : null,
                          image: DecorationImage(
                            image: AssetImage(assetPath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(tr('settings_wallpaper_from_gallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (WallpaperService().type != 'none') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      tr('settings_wallpaper_dim'),
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                    Expanded(
                      child: Slider(
                        value: WallpaperService().dim,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        activeColor: colorScheme.primary,
                        onChanged: (v) => WallpaperService().setDim(v),
                      ),
                    ),
                    Text(
                      '${(WallpaperService().dim * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                    image: WallpaperService().getBoxDecoration(context)?.image,
                    color: WallpaperService().getBoxDecoration(context) == null
                        ? cardColor : null,
                  ),
                  child: WallpaperService().getBoxDecoration(context) == null
                      ? Center(child: Text('Preview', style: TextStyle(color: textColor.withValues(alpha: 0.5))))
                      : null,
                ),
              ],
              const SizedBox(height: 24),
            ],

            // ── Section: Theme ──
            Text(
              tr('settings_theme'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text(
                  tr('settings_theme_amoled_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  tr('settings_theme_amoled_desc'),
                  style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                ),
                value: _amoledDarkEnabled,
                activeThumbColor: colorScheme.primary,
                onChanged: (bool value) {
                  setState(() => _amoledDarkEnabled = value);
                  ThemeService().setAmoledDark(value);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              tr('settings_save_btn'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
