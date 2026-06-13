import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'tables/categories_table.dart';
part 'tables/products_table.dart';
part 'tables/customers_table.dart';
part 'tables/transactions_table.dart';
part 'tables/transaction_items_table.dart';
part 'tables/debts_table.dart';
part 'tables/stock_movements_table.dart';
part 'tables/cash_flows_table.dart';
part 'tables/settings_table.dart';
part 'tables/sync_queue_table.dart';
part 'tables/users_table.dart';

part 'daos/products_dao.dart';
part 'daos/categories_dao.dart';
part 'daos/transactions_dao.dart';
part 'daos/customers_dao.dart';
part 'daos/debts_dao.dart';
part 'daos/reports_dao.dart';
part 'daos/sync_dao.dart';
part 'daos/stock_movements_dao.dart';
part 'daos/settings_dao.dart';
part 'daos/users_dao.dart';

part 'app_database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kasirku.db'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(
  tables: [
    Categories, Products, Customers, Transactions,
    TransactionItems, Debts, StockMovements,
    CashFlows, Settings, SyncQueue, Users,
  ],
  daos: [
    ProductsDao, CategoriesDao, TransactionsDao,
    CustomersDao, DebtsDao, ReportsDao, SyncDao,
    StockMovementsDao, SettingsDao, UsersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaults();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await customStatement(
          "CREATE TABLE IF NOT EXISTS users ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT,"
          "name TEXT NOT NULL,"
          "pin TEXT NOT NULL,"
          "role TEXT NOT NULL DEFAULT 'kasir',"
          "is_active INTEGER NOT NULL DEFAULT 1,"
          "created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)"
          ")"
        );
        await customStatement(
          "CREATE TABLE IF NOT EXISTS sync_queue ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT,"
          "table_name TEXT NOT NULL,"
          "record_id INTEGER NOT NULL,"
          "action TEXT NOT NULL,"
          "created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)"
          ")"
        );
      }
      if (from < 3) {
        await customStatement(
          "ALTER TABLE transactions ADD COLUMN kasir_id INTEGER REFERENCES users(id)"
        );
        await customStatement(
          "ALTER TABLE transactions ADD COLUMN kasir_name TEXT"
        );
        // SHA-256 dari '1234'
        await customStatement(
          "INSERT OR IGNORE INTO users (name, pin, role, is_active) "
          "SELECT 'Admin',"
          "'03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',"
          "'admin', 1 "
          "WHERE NOT EXISTS (SELECT 1 FROM users LIMIT 1)"
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _insertDefaults() async {
    final cats = ['Makanan', 'Minuman', 'Snack', 'Rokok',
                  'Sembako', 'Kebersihan', 'Kesehatan', 'Lainnya'];
    for (final name in cats) {
      await into(categories).insert(CategoriesCompanion.insert(name: name));
    }
    await into(settings).insert(
      SettingsCompanion.insert(key: 'toko_nama', value: const Value('KasirKu')));
    // Admin default PIN 1234 (SHA-256)
    await into(users).insert(UsersCompanion.insert(
      name: 'Admin',
      pin: '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
      role: const Value('admin'),
    ));
  }

  Future<void> resetAllData() async {
    await transaction(() async {
      await delete(transactionItems).go();
      await delete(transactions).go();
      await delete(debts).go();
      await delete(stockMovements).go();
      await delete(syncQueue).go();
      await (update(products)).write(const ProductsCompanion(stock: Value(0)));
      await (update(customers)).write(const CustomersCompanion(points: Value(0)));
    });
  }
}
