part of '../app_database.dart';

@DriftAccessor(tables: [Transactions, TransactionItems, Products])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Future<int> insertTransaction(
    TransactionsCompanion transaction,
    List<TransactionItemsCompanion> items,
  ) async {
    return db.transaction(() async {
      final txId = await into(transactions).insert(transaction);
      for (final item in items) {
        await into(transactionItems).insert(
          item.copyWith(transactionId: Value(txId))
        );
        final product = await (select(products)
          ..where((t) => t.id.equals(item.productId.value)))
            .getSingle();
        await (update(products)
          ..where((t) => t.id.equals(item.productId.value)))
            .write(ProductsCompanion(
              stock: Value(product.stock - item.quantity.value)
            ));
      }
      return txId;
    });
  }

  Future<List<Transaction>> getTransactionsByDate(
    DateTime start, DateTime end) =>
      (select(transactions)
        ..where((t) => t.createdAt.isBetweenValues(start, end))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<Map<String, dynamic>> getTodaySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final txList = await getTransactionsByDate(start, end);
    final omzet = txList.fold<double>(0, (s, t) => s + t.total);
    return {'omzet': omzet, 'jumlah_transaksi': txList.length};
  }

  Future<List<TransactionItem>> getTransactionItems(int transactionId) =>
      (select(transactionItems)
        ..where((t) => t.transactionId.equals(transactionId)))
          .get();

  Future<String> generateInvoiceNumber() async {
    final now = DateTime.now();
    final prefix =
        'INV${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final start = DateTime(now.year, now.month, now.day);
    final result = await (selectOnly(transactions)
      ..addColumns([transactions.id.count()])
      ..where(transactions.createdAt.isBiggerOrEqualValue(start)))
        .getSingle();
    final num = (result.read(transactions.id.count()) ?? 0) + 1;
    return '$prefix${num.toString().padLeft(4,'0')}';
  }

  Stream<List<Transaction>> watchTodayTransactions() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (select(transactions)
      ..where((t) => t.createdAt.isBetweenValues(start, end))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
