import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/system_models.dart';
import 'offline_sync_service.dart';

class NotificationNotifier extends StateNotifier<List<SystemNotification>> {
  final Ref ref;

  NotificationNotifier(this.ref) : super([]) {
    _loadFromCache();
  }

  Future<void> loadNotifications() async {
    _loadFromCache();
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.notificationsBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.notificationsBoxName);
        final list = box.values
            .map((e) =>
                SystemNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = list;
      }
    } catch (_) {}
  }

  Future<void> addNotification(dynamic p1, [dynamic p2]) async {
    if (p1 is SystemNotification) {
      state = [p1, ...state];
    } else if (p1 is String) {
      final notif = SystemNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: p1,
        message: p2?.toString() ?? '',
        createdAt: DateTime.now(),
      );
      state = [notif, ...state];
    }
  }

  Future<void> deleteNotification(String id) async {
    state = state.where((n) => n.id != id).toList();
  }

  Future<void> markAllAsRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  Future<void> markAsRead(String id) async {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<SystemNotification>>(
        (ref) {
  return NotificationNotifier(ref);
});
