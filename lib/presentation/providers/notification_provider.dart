import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'products_provider.dart';

// ─── Model Notifikasi ─────────────────────────────────────────────────────────

enum NotifType { stokHampirHabis, stokHabis, scanBarcode, info }

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
}

// ─── Notification Notifier ────────────────────────────────────────────────────

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  void add(AppNotification notif) {
    // Hindari duplikat id
    if (state.any((n) => n.id == notif.id)) return;
    state = [notif, ...state];
  }

  void markRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
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
          final id = isOut ? 'out_${p.id}' : 'low_${p.id}';
          notifier.add(AppNotification(
            id: id,
            type: isOut ? NotifType.stokHabis : NotifType.stokHampirHabis,
            title: isOut ? 'Stok Habis!' : 'Stok Hampir Habis',
            message: isOut
                ? '${p.name} sudah habis. Segera restok!'
                : '${p.name} tinggal ${p.stock} ${p.unit} (min: ${p.minStock})',
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
