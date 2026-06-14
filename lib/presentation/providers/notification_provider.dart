import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'products_provider.dart';

// ─── Model Notifikasi ─────────────────────────────────────────────────────────

enum NotifType { stokHampirHabis, stokHabis, hutangJatuhTempo, scanBarcode, info }

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String message;
  final DateTime time;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        time: time,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'message': message,
    'time': time.millisecondsSinceEpoch,
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'],
    type: NotifType.values[json['type']],
    title: json['title'],
    message: json['message'],
    time: DateTime.fromMillisecondsSinceEpoch(json['time']),
    isRead: json['isRead'] ?? false,
  );
}

// ─── Notification Notifier ────────────────────────────────────────────────────

const _kNotifKey = 'app_notifications';

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNotifKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => AppNotification.fromJson(e))
            .toList();
        state = list;
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kNotifKey, jsonEncode(state.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }

  void add(AppNotification notif) {
    if (state.any((n) => n.id == notif.id)) return;
    state = [notif, ...state];
    _save();
  }

  void markRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    _save();
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _save();
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
    _save();
  }

  void clearAll() {
    state = [];
    _save();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) {
    final notifier = NotificationNotifier();

    // Watch lowStock → otomatis generate notif stok
    ref.listen(lowStockProvider, (prev, next) {
      next.whenData((products) {
        for (final p in products) {
          final isOut = p.stock <= 0;
          final id = isOut ? 'out_\${p.id}' : 'low_\${p.id}';
          notifier.add(AppNotification(
            id: id,
            type: isOut ? NotifType.stokHabis : NotifType.stokHampirHabis,
            title: isOut ? 'Stok Habis!' : 'Stok Hampir Habis',
            message: isOut
                ? '\${p.name} sudah habis. Segera restok!'
                : '\${p.name} tinggal \${p.stock} \${p.unit} (min: \${p.minStock})',
            time: DateTime.now(),
          ));
        }
      });
    });

    return notifier;
  },
);

// Helper: unread count
final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationProvider);
  return notifs.where((n) => !n.isRead).length;
});
