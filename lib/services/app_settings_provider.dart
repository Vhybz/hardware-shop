import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'offline_sync_service.dart';

class AppSettings {
  final bool pushNotificationsEnabled;
  final bool systemSoundsEnabled;
  final bool hapticFeedbackEnabled;
  final bool enableWholesale;
  final double storeLat;
  final double storeLon;
  final double storeRadiusMeters;

  AppSettings({
    this.pushNotificationsEnabled = true,
    this.systemSoundsEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.enableWholesale = true,
    this.storeLat = 7.35134,
    this.storeLon = -2.31961,
    this.storeRadiusMeters = 50.0,
  });

  AppSettings copyWith({
    bool? pushNotificationsEnabled,
    bool? systemSoundsEnabled,
    bool? hapticFeedbackEnabled,
    bool? enableWholesale,
    double? storeLat,
    double? storeLon,
    double? storeRadiusMeters,
  }) {
    return AppSettings(
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      systemSoundsEnabled: systemSoundsEnabled ?? this.systemSoundsEnabled,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      enableWholesale: enableWholesale ?? this.enableWholesale,
      storeLat: storeLat ?? this.storeLat,
      storeLon: storeLon ?? this.storeLon,
      storeRadiusMeters: storeRadiusMeters ?? this.storeRadiusMeters,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings()) {
    _init();
  }

  void _init() {
    final box = Hive.box(OfflineSyncService.settingsBoxName);
    state = AppSettings(
      pushNotificationsEnabled: box.get('push_notifications', defaultValue: true),
      systemSoundsEnabled: box.get('system_sounds', defaultValue: true),
      hapticFeedbackEnabled: box.get('haptic_feedback', defaultValue: true),
      enableWholesale: box.get('enable_wholesale', defaultValue: true),
      storeLat: (box.get('store_lat', defaultValue: 7.35134) as num).toDouble(),
      storeLon: (box.get('store_lon', defaultValue: -2.31961) as num).toDouble(),
      storeRadiusMeters: (box.get('store_radius', defaultValue: 50.0) as num).toDouble(),
    );
  }

  void toggleWholesale(bool value) {
    state = state.copyWith(enableWholesale: value);
    _save('enable_wholesale', value);
  }

  void togglePushNotifications(bool value) {
    state = state.copyWith(pushNotificationsEnabled: value);
    _save('push_notifications', value);
  }

  void toggleSystemSounds(bool value) {
    state = state.copyWith(systemSoundsEnabled: value);
    _save('system_sounds', value);
  }

  void toggleHapticFeedback(bool value) {
    state = state.copyWith(hapticFeedbackEnabled: value);
    _save('haptic_feedback', value);
  }

  void updateStoreCoordinates({required double lat, required double lon, double? radius}) {
    state = state.copyWith(
      storeLat: lat,
      storeLon: lon,
      storeRadiusMeters: radius ?? state.storeRadiusMeters,
    );
    _save('store_lat', lat);
    _save('store_lon', lon);
    if (radius != null) {
      _save('store_radius', radius);
    }
  }

  void _save(String key, dynamic value) {
    final box = Hive.box(OfflineSyncService.settingsBoxName);
    box.put(key, value);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
