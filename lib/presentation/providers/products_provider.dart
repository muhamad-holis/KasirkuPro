import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import 'database_provider.dart';

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(databaseProvider).productsDao.watchAllProducts();
});

final productSearchProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final query = ref.watch(productSearchProvider);
  final db = ref.watch(databaseProvider);
  if (query.isEmpty) return db.productsDao.getAllProducts();
  return db.productsDao.searchProducts(query);
});

final lowStockProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(databaseProvider).productsDao.watchLowStock();
});
