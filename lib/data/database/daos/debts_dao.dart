part of '../app_database.dart';

@DriftAccessor(tables: [Debts, Customers])
class DebtsDao extends DatabaseAccessor<AppDatabase>
    with _$DebtsDaoMixin {
  DebtsDao(super.db);

  Future<List<Debt>> getAllDebts() => select(debts).get();
  Future<List<Debt>> getUnpaidDebts() =>
      (select(debts)..where((t) => t.status.equals('unpaid'))).get();
  Stream<List<Debt>> watchDebts() => select(debts).watch();
  Future<int> insertDebt(DebtsCompanion d) => into(debts).insert(d);

  Future<void> payDebt(int id, double amount) async {
    final debt = await (select(debts)
      ..where((t) => t.id.equals(id))).getSingle();
    final newPaid = debt.paidAmount + amount;
    final newStatus = newPaid >= debt.amount ? 'paid' : 'partial';
    await (update(debts)..where((t) => t.id.equals(id)))
        .write(DebtsCompanion(
          paidAmount: Value(newPaid),
          status: Value(newStatus),
        ));
  }
}
