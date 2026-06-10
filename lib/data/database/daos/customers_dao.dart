part of '../app_database.dart';

@DriftAccessor(tables: [Customers])
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Future<List<Customer>> getAllCustomers() => select(customers).get();
  Stream<List<Customer>> watchCustomers() => select(customers).watch();
  Future<int> insertCustomer(CustomersCompanion c) => into(customers).insert(c);
  Future<bool> updateCustomer(CustomersCompanion c) => update(customers).replace(c);
  Future<List<Customer>> searchCustomers(String q) =>
      (select(customers)
        ..where((t) => t.name.like('%$q%') | t.phone.like('%$q%')))
          .get();
}
