import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import 'offline_sync_service.dart';

class ThemeState {
  final ThemeMode mode;
  final Color primaryColor;

  ThemeState({
    required this.mode,
    required this.primaryColor,
  });

  ThemeState copyWith({
    ThemeMode? mode,
    Color? primaryColor,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final Ref ref;

  ThemeNotifier(this.ref)
      : super(ThemeState(
          mode: ThemeMode.light,
          primaryColor: AppColors.primaryMaroon,
        )) {
    _init();
  }

  void _init() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.settingsBoxName)) {
        final box = Hive.box(OfflineSyncService.settingsBoxName);
        final String? savedMode = box.get('theme_mode');
        final int? savedColor = box.get('theme_color');

        state = ThemeState(
          mode: _stringToMode(savedMode),
          primaryColor:
              savedColor != null ? Color(savedColor) : AppColors.primaryMaroon,
        );
      }
    } catch (_) {}
  }

  void toggleTheme(bool isDarkMode) {
    final newMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _saveToLocal(mode, state.primaryColor);
  }

  void setPrimaryColor(Color color) {
    state = state.copyWith(primaryColor: color);
    _saveToLocal(state.mode, color);
  }

  void _saveToLocal(ThemeMode mode, Color color) {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.settingsBoxName)) {
        final box = Hive.box(OfflineSyncService.settingsBoxName);
        box.put('theme_mode', mode.name);
        box.put('theme_color', color.toARGB32());
      }
    } catch (_) {}
  }

  ThemeMode _stringToMode(String? mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(ref);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).mode;
});
