import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;

  CartItem({required this.product, this.quantity = 1, this.discount = 0});

  double get subtotal => (product.sellPrice * quantity) - discount;

  CartItem copyWith({int? quantity, double? discount}) => CartItem(
    product: product,
    quantity: quantity ?? this.quantity,
    discount: discount ?? this.discount,
  );
}

class KasirState {
  final List<CartItem> items;
  final double discountTotal;
  final double taxPercent;
  final String paymentMethod;
  final double amountPaid;

  const KasirState({
    this.items = const [],
    this.discountTotal = 0,
    this.taxPercent = 0,
    this.paymentMethod = 'tunai',
    this.amountPaid = 0,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.subtotal);
  double get taxAmount => subtotal * (taxPercent / 100);
  double get total => subtotal - discountTotal + taxAmount;
  double get change => amountPaid - total;
  bool get isEmpty => items.isEmpty;

  KasirState copyWith({
    List<CartItem>? items,
    double? discountTotal,
    double? taxPercent,
    String? paymentMethod,
    double? amountPaid,
  }) => KasirState(
    items: items ?? this.items,
    discountTotal: discountTotal ?? this.discountTotal,
    taxPercent: taxPercent ?? this.taxPercent,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    amountPaid: amountPaid ?? this.amountPaid,
  );
}

class KasirNotifier extends StateNotifier<KasirState> {
  KasirNotifier() : super(const KasirState());

  void addProduct(Product product) {
    final items = [...state.items];
    final idx = items.indexWhere((i) => i.product.id == product.id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + 1);
    } else {
      items.add(CartItem(product: product));
    }
    state = state.copyWith(items: items);
  }

  void removeProduct(int productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.product.id != productId).toList());
  }

  void updateQuantity(int productId, int qty) {
    if (qty <= 0) { removeProduct(productId); return; }
    state = state.copyWith(
      items: state.items.map((i) =>
        i.product.id == productId ? i.copyWith(quantity: qty) : i).toList());
  }

  void setDiscount(double v) => state = state.copyWith(discountTotal: v);
  void setTax(double v)      => state = state.copyWith(taxPercent: v);
  void setPaymentMethod(String v) => state = state.copyWith(paymentMethod: v);
  void setAmountPaid(double v)    => state = state.copyWith(amountPaid: v);
  void clear() => state = const KasirState();
}

final kasirProvider =
    StateNotifierProvider<KasirNotifier, KasirState>((ref) => KasirNotifier());
