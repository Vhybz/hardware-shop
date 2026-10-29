import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import 'user_provider.dart';
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
  
  ThemeNotifier(this.ref) : super(ThemeState(
    mode: ThemeMode.light,
    primaryColor: AppColors.primaryMaroon,
  )) {
    _init();
  }

  void _init() {
    // 1. Load from local Hive first for instant boot
    final box = Hive.box(OfflineSyncService.settingsBoxName);
    final String? savedMode = box.get('theme_mode');
    final int? savedColor = box.get('theme_color');

    state = ThemeState(
      mode: _stringToMode(savedMode),
      primaryColor: savedColor != null ? Color(savedColor) : AppColors.primaryMaroon,
    );

    // 2. Listen to currentUser changes to sync account preferences
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null) {
        bool changed = false;
        ThemeMode newMode = state.mode;
        Color newColor = state.primaryColor;

        if (next.themeMode != null) {
          final mode = _stringToMode(next.themeMode);
          if (mode != state.mode) {
            newMode = mode;
            changed = true;
          }
        }

        if (next.themePrimaryColor != null) {
          final color = Color(next.themePrimaryColor!);
          if (color.toARGB32() != state.primaryColor.toARGB32()) {
            newColor = color;
            changed = true;
          }
        }

        if (changed) {
          state = state.copyWith(mode: newMode, primaryColor: newColor);
          _saveToLocal(newMode, newColor);
        }
      }
    });
  }

  void toggleTheme(bool isDarkMode) {
    final newMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _saveToLocal(mode, state.primaryColor);
    _saveToRemote(mode: mode);
  }

  void setPrimaryColor(Color color) {
    state = state.copyWith(primaryColor: color);
    _saveToLocal(state.mode, color);
    _saveToRemote(color: color);
  }

  void _saveToLocal(ThemeMode mode, Color color) {
    final box = Hive.box(OfflineSyncService.settingsBoxName);
    box.put('theme_mode', mode.name);
    box.put('theme_color', color.toARGB32());
  }

  void _saveToRemote({ThemeMode? mode, Color? color}) {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      ref.read(userProvider.notifier).updateTheme(
        user.id,
        mode: mode?.name ?? state.mode.name,
        color: color?.toARGB32() ?? state.primaryColor.toARGB32(),
      );
    }
  }

  ThemeMode _stringToMode(String? mode) {
    switch (mode) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.light;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(ref);
});
