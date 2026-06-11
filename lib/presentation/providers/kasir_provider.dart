import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';
import 'database_provider.dart';

class CartItem {
  final Product product;
  final int quantity;
  final double discount;

  const CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0,
  });

  double get subtotal =>
      (product.sellPrice - discount) * quantity;

  CartItem copyWith({int? quantity, double? discount}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        discount: discount ?? this.discount,
      );
}

class KasirState {
  final List<CartItem> cart;
  final String paymentMethod;
  final double amountPaid;
  final double discountGlobal;
  final Customer? selectedCustomer;
  final bool isProcessing;
  final String? lastInvoice;
  final String searchQuery;

  const KasirState({
    this.cart = const [],
    this.paymentMethod = 'tunai',
    this.amountPaid = 0,
    this.discountGlobal = 0,
    this.selectedCustomer,
    this.isProcessing = false,
    this.lastInvoice,
    this.searchQuery = '',
  });

  double get subtotal =>
      cart.fold(0, (s, i) => s + i.subtotal);

  double get totalDiscount =>
      discountGlobal + cart.fold(0, (s, i) => s + i.discount * i.quantity);

  double get tax => 0;

  double get total =>
      (subtotal - discountGlobal + tax).clamp(0, double.infinity);

  double get change =>
      (amountPaid - total).clamp(0, double.infinity);

  int get totalItems =>
      cart.fold(0, (s, i) => s + i.quantity);

  bool get cartIsEmpty => cart.isEmpty;

  KasirState copyWith({
    List<CartItem>? cart,
    String? paymentMethod,
    double? amountPaid,
    double? discountGlobal,
    Customer? selectedCustomer,
    bool? isProcessing,
    String? lastInvoice,
    String? searchQuery,
    bool clearCustomer = false,
    bool clearLastInvoice = false,
  }) =>
      KasirState(
        cart: cart ?? this.cart,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        amountPaid: amountPaid ?? this.amountPaid,
        discountGlobal: discountGlobal ?? this.discountGlobal,
        selectedCustomer:
            clearCustomer ? null : selectedCustomer ?? this.selectedCustomer,
        isProcessing: isProcessing ?? this.isProcessing,
        lastInvoice:
            clearLastInvoice ? null : lastInvoice ?? this.lastInvoice,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

class KasirNotifier extends StateNotifier<KasirState> {
  final Ref _ref;

  KasirNotifier(this._ref) : super(const KasirState());

  AppDatabase get _db => _ref.read(databaseProvider);

  void addProduct(Product product) {
    final cart = [...state.cart];
    final idx = cart.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      cart[idx] = cart[idx].copyWith(quantity: cart[idx].quantity + 1);
    } else {
      cart.add(CartItem(product: product));
    }
    state = state.copyWith(cart: cart);
  }

  void removeProduct(int productId) {
    state = state.copyWith(
      cart: state.cart.where((i) => i.product.id != productId).toList(),
    );
  }

  void updateQuantity(int productId, int qty) {
    if (qty <= 0) {
      removeProduct(productId);
      return;
    }
    state = state.copyWith(
      cart: state.cart
          .map((i) =>
              i.product.id == productId ? i.copyWith(quantity: qty) : i)
          .toList(),
    );
  }

  void updateItemDiscount(int productId, double discount) {
    state = state.copyWith(
      cart: state.cart
          .map((i) =>
              i.product.id == productId ? i.copyWith(discount: discount) : i)
          .toList(),
    );
  }

  void clearCart() {
    state = const KasirState();
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setAmountPaid(double amount) {
    state = state.copyWith(amountPaid: amount);
  }

  void setDiscountGlobal(double discount) {
    state = state.copyWith(discountGlobal: discount);
  }

  void setCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(selectedCustomer: customer);
    }
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  Future<String?> processTransaction() async {
    if (state.cart.isEmpty) return null;

    state = state.copyWith(isProcessing: true);
    try {
      final invoice =
          await _db.transactionsDao.generateInvoiceNumber();

      final txCompanion = TransactionsCompanion.insert(
        invoiceNumber: invoice,
        customerId: Value(state.selectedCustomer?.id),
        subtotal: Value(state.subtotal),
        discountAmount: Value(state.discountGlobal),
        taxAmount: Value(state.tax),
        total: Value(state.total),
        amountPaid: Value(state.amountPaid),
        change: Value(state.change),
        paymentMethod: Value(state.paymentMethod),
        status: const Value('completed'),
      );

      final items = state.cart
          .map(
            (i) => TransactionItemsCompanion.insert(
              transactionId: 0,
              productId: i.product.id,
              productName: i.product.name,
              price: i.product.sellPrice,
              quantity: i.quantity,
              discount: Value(i.discount),
              subtotal: i.subtotal,
            ),
          )
          .toList();

      await _db.transactionsDao.insertTransaction(txCompanion, items);

      state = state.copyWith(
        isProcessing: false,
        lastInvoice: invoice,
      );
      return invoice;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  void resetAfterTransaction() {
    state = const KasirState();
  }
}

final kasirProvider =
    StateNotifierProvider<KasirNotifier, KasirState>((ref) {
  return KasirNotifier(ref);
});

final kasirProductSearchProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  final db = ref.watch(databaseProvider);
  if (query.trim().isEmpty) return db.productsDao.getAllProducts();
  return db.productsDao.searchProducts(query);
});

final kasirCustomerListProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(databaseProvider).customersDao.getAllCustomers();
});
