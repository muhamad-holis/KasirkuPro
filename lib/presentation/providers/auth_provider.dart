import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart'; // <-- Import tambahan untuk Value()
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import 'database_provider.dart';

// ─── Helper hash PIN ──────────────────────────────────────────────────────────

String hashPin(String pin) =>
    sha256.convert(utf8.encode(pin)).toString();

// ─── Model user aktif ─────────────────────────────────────────────────────────

class ActiveUser {
  final int id;
  final String name;
  final String role;

  const ActiveUser({
    required this.id,
    required this.name,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  @override
  String toString() => name;
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<ActiveUser?> {
  AuthNotifier(this._ref) : super(null) {
    _initDefaultAdmin();
  }

  final Ref _ref;
  AppDatabase get _db => _ref.read(databaseProvider);

  /// Pastikan ada minimal 1 admin saat app pertama kali dipakai
  Future<void> _initDefaultAdmin() async {
    final users = await _db.usersDao.getAllUsers();
    if (users.isEmpty) {
      await _db.usersDao.insertUser(UsersCompanion.insert(
        name: 'Admin',
        pin: hashPin('1234'),
        role: const Value('admin'),
      ));
    }
  }

  /// Login. Return null = sukses, string = pesan error.
  Future<String?> login(String name, String pin) async {
    final users = await _db.usersDao.getActiveUsers();
    final hashed = hashPin(pin);
    final match = users.where((u) =>
        u.name.toLowerCase() == name.toLowerCase().trim() &&
        u.pin == hashed).toList();

    if (match.isEmpty) return 'Nama atau PIN salah';

    final user = match.first;
    state = ActiveUser(id: user.id, name: user.name, role: user.role);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_user_id', user.id);
    await prefs.setString('last_user_name', user.name);
    await prefs.setString('last_user_role', user.role);

    return null;
  }

  Future<void> logout() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_user_id');
    await prefs.remove('last_user_name');
    await prefs.remove('last_user_role');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, ActiveUser?>(
  (ref) => AuthNotifier(ref),
);

// ─── Provider list semua user (untuk halaman kelola kasir) ────────────────────

final allUsersProvider = FutureProvider.autoDispose<List<User>>((ref) =>
    ref.watch(databaseProvider).usersDao.getAllUsers());
