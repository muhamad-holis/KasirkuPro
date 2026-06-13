part of '../app_database.dart';

@DriftAccessor(tables: [Transactions, TransactionItems, Products, Customers])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Insert transaksi + kurangi stok + beri poin otomatis ke pelanggan.
  /// [customerId] opsional — bisa diisi untuk semua metode pembayaran.
  /// Poin = 1 poin per Rp 10.000 yang dibayar.
  Future<int> insertTransaction(
    TransactionsCompanion transaction,
    List<TransactionItemsCompanion> items, {
    int? customerId,
    int? kasirId,
    String? kasirName,
  }) async {
    return db.transaction(() async {
      var txCompanion = transaction;
      if (customerId != null) {
        txCompanion = txCompanion.copyWith(customerId: Value(customerId));
      }
      if (kasirId != null) {
        txCompanion = txCompanion.copyWith(kasirId: Value(kasirId));
      }
      if (kasirName != null) {
        txCompanion = txCompanion.copyWith(kasirName: Value(kasirName));
      }

      final txId = await into(transactions).insert(txCompanion);

      for (final item in items) {
        await into(transactionItems).insert(
          item.copyWith(transactionId: Value(txId)),
        );
        final product = await (select(products)
              ..where((t) => t.id.equals(item.productId.value)))
            .getSingle();
        await (update(products)
              ..where((t) => t.id.equals(item.productId.value)))
            .write(ProductsCompanion(
              stock: Value(product.stock - item.quantity.value),
            ));
      }

      // Poin otomatis: 1 poin per Rp 10.000
      if (customerId != null) {
        final total = transaction.total.value;
        final earnedPoints = (total / 10000).floor();
        if (earnedPoints > 0) {
          final customer = await (select(customers)
                ..where((c) => c.id.equals(customerId)))
              .getSingleOrNull();
          if (customer != null) {
            await (update(customers)
                  ..where((c) => c.id.equals(customerId)))
                .write(CustomersCompanion(
                  points: Value(customer.points + earnedPoints),
                ));
          }
        }
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

  /// Riwayat transaksi per pelanggan
  Future<List<Transaction>> getTransactionsByCustomer(int customerId) =>
      (select(transactions)
        ..where((t) => t.customerId.equals(customerId))
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
        'INV${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final start = DateTime(now.year, now.month, now.day);
    final result = await (selectOnly(transactions)
          ..addColumns([transactions.id.count()])
          ..where(transactions.createdAt.isBiggerOrEqualValue(start)))
        .getSingle();
    final num = (result.read(transactions.id.count()) ?? 0) + 1;
    return '$prefix${num.toString().padLeft(4, '0')}';
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
