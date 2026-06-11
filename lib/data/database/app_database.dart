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
    StockMovementsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaults();
    },
  );

  Future<void> _insertDefaults() async {
    final cats = ['Makanan','Minuman','Snack','Rokok',
                  'Sembako','Kebersihan','Kesehatan','Lainnya'];
    for (final name in cats) {
      await into(categories).insert(CategoriesCompanion.insert(name: name));
    }
    await into(settings).insert(
      SettingsCompanion.insert(key: 'toko_nama', value: const Value('KasirKu')));
  }
}
