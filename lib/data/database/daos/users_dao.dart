part of '../app_database.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<List<User>> getAllUsers() =>
      (select(users)..orderBy([(u) => OrderingTerm.asc(u.name)])).get();

  Future<List<User>> getActiveUsers() =>
      (select(users)
        ..where((u) => u.isActive.equals(true))
        ..orderBy([(u) => OrderingTerm.asc(u.name)]))
          .get();

  Future<int> insertUser(UsersCompanion user) =>
      into(users).insert(user);

  Future<bool> updateUser(UsersCompanion user) =>
      update(users).replace(user);

  Future<int> softDeleteUser(int id) =>
      (update(users)..where((u) => u.id.equals(id)))
          .write(const UsersCompanion(isActive: Value(false)));

  Future<User?> getUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
}
