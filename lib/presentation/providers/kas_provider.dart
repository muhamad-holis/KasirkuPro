// lib/presentation/providers/kas_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Provider untuk Kas & Laporan Laba Rugi (P3)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class KasSummary {
  final double totalIncome;
  final double totalExpense;
  final double saldo;

  const KasSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.saldo,
  });
}

class LabaRugiData {
  /// Omzet penjualan (dari tabel transactions)
  final double omzet;

  /// HPP = SUM(buyPrice * quantity) dari transaction_items
  final double hpp;

  /// Laba kotor = omzet - hpp
  double get labaKotor => omzet - hpp;

  /// Kas masuk non-penjualan (modal, dll)
  final double kasIncome;

  /// Kas keluar operasional
  final double kasExpense;

  /// Laba bersih = labaKotor + kasIncome - kasExpense
  double get labaBersih => labaKotor + kasIncome - kasExpense;

  /// Margin persentase
  double get marginPersen =>
      omzet == 0 ? 0 : (labaBersih / omzet) * 100;

  const LabaRugiData({
    required this.omzet,
    required this.hpp,
    required this.kasIncome,
    required this.kasExpense,
  });
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Summary kas (masuk, keluar, saldo)
final kasSummaryProvider =
    FutureProvider.family<KasSummary, DateRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  final report =
      await db.reportsDao.getCashReport(range.start, range.end);

  return KasSummary(
    totalIncome: report['income'] ?? 0,
    totalExpense: report['expense'] ?? 0,
    saldo: report['saldo'] ?? 0,
  );
});

/// Laporan Laba Rugi
final labaRugiProvider =
    FutureProvider.family<LabaRugiData, DateRange>((ref, range) async {
  final db = ref.watch(databaseProvider);

  // 1. Omzet dari transaksi penjualan
  final transactions =
      await db.transactionsDao.getTransactionsByDate(range.start, range.end);
  final omzet = transactions.fold<double>(0, (s, t) => s + t.total);

  // 2. HPP: ambil semua items dan hitung buyPrice * qty
  double hpp = 0;
  for (final tx in transactions) {
    final items = await db.transactionsDao.getTransactionItems(tx.id);
    for (final item in items) {
      // Cari buyPrice dari produk
      final allProducts = await db.productsDao.getAllProducts();
      final product = allProducts.where((p) => p.id == item.productId);
      if (product.isNotEmpty) {
        hpp += product.first.buyPrice * item.quantity;
      }
    }
  }

  // 3. Kas masuk non-penjualan (exclude category 'penjualan')
  final kasReport = await db.reportsDao.getCashReport(range.start, range.end);
  
  // Ambil cash flows untuk pemilahan lebih detail
  final cashFlows = await db.reportsDao
      .watchCashFlows(range.start, range.end)
      .first;

  double kasIncome = 0;
  double kasExpense = 0;

  for (final f in cashFlows) {
    if (f.type == 'income' && f.category != 'penjualan') {
      kasIncome += f.amount;
    } else if (f.type == 'expense') {
      kasExpense += f.amount;
    }
  }

  return LabaRugiData(
    omzet: omzet,
    hpp: hpp,
    kasIncome: kasIncome,
    kasExpense: kasExpense,
  );
});

/// Dashboard summary kas hari ini
final kasHariIniProvider = FutureProvider<KasSummary>((ref) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  return ref.watch(kasSummaryProvider(DateRange(start: start, end: end)).future);
});
