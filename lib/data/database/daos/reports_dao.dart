part of '../app_database.dart';

@DriftAccessor(tables: [Transactions, TransactionItems, Products, StockMovements, CashFlows])
class ReportsDao extends DatabaseAccessor<AppDatabase>
    with _$ReportsDaoMixin {
  ReportsDao(super.db);

  Future<List<Map<String, dynamic>>> getTopProducts(
    DateTime start, DateTime end, {int limit = 10}) async {
    final query = db.customSelect(
      '''
      SELECT p.id, p.name,
        SUM(ti.quantity) as total_qty,
        SUM(ti.subtotal) as total_omzet
      FROM transaction_items ti
      JOIN products p ON ti.product_id = p.id
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.created_at BETWEEN ? AND ?
      GROUP BY p.id ORDER BY total_qty DESC LIMIT ?
      ''',
      variables: [
        Variable(start.toIso8601String()),
        Variable(end.toIso8601String()),
        Variable(limit),
      ],
      readsFrom: {transactionItems, products, transactions},
    );
    return query.get().then((rows) => rows.map((r) => r.data).toList());
  }

  Future<List<Map<String, dynamic>>> getDailySalesChart(
    DateTime start, DateTime end) async {
    final query = db.customSelect(
      '''
      SELECT DATE(created_at) as tanggal,
        SUM(total) as omzet, COUNT(*) as jumlah
      FROM transactions
      WHERE created_at BETWEEN ? AND ? AND status = 'completed'
      GROUP BY DATE(created_at) ORDER BY tanggal ASC
      ''',
      variables: [
        Variable(start.toIso8601String()),
        Variable(end.toIso8601String()),
      ],
      readsFrom: {transactions},
    );
    return query.get().then((rows) => rows.map((r) => r.data).toList());
  }

  Future<Map<String, double>> getCashReport(
    DateTime start, DateTime end) async {
    final inc = await db.customSelect(
      'SELECT COALESCE(SUM(amount),0) as total FROM cash_flows WHERE type="income" AND created_at BETWEEN ? AND ?',
      variables: [Variable(start.toIso8601String()), Variable(end.toIso8601String())],
      readsFrom: {cashFlows},
    ).getSingle();
    final exp = await db.customSelect(
      'SELECT COALESCE(SUM(amount),0) as total FROM cash_flows WHERE type="expense" AND created_at BETWEEN ? AND ?',
      variables: [Variable(start.toIso8601String()), Variable(end.toIso8601String())],
      readsFrom: {cashFlows},
    ).getSingle();
    final i = (inc.data['total'] as num).toDouble();
    final e = (exp.data['total'] as num).toDouble();
    return {'income': i, 'expense': e, 'saldo': i - e};
  }
}
