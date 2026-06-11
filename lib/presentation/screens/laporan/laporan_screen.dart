import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key});

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _period = '7d';
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  DateTime get _start {
    final now = DateTime.now();
    switch (_period) {
      case 'today': return DateTime(now.year, now.month, now.day);
      case '7d':    return now.subtract(const Duration(days: 7));
      case '30d':   return now.subtract(const Duration(days: 30));
      default:      return DateTime(now.year, now.month, 1);
    }
  }

  String get _periodLabel {
    switch (_period) {
      case 'today': return 'Hari Ini';
      case '7d':    return '7 Hari Terakhir';
      case '30d':   return '30 Hari Terakhir';
      default:      return 'Bulan Ini';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan',
          style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          _exportingPdf
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Export PDF',
                  onPressed: _exportPdf,
                ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Penjualan'),
            Tab(text: 'Kas'),
            Tab(text: 'Stok'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter periode
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _Chip('Hari Ini', 'today', _period,
                  (v) => setState(() => _period = v)),
                _Chip('7 Hari', '7d', _period,
                  (v) => setState(() => _period = v)),
                _Chip('30 Hari', '30d', _period,
                  (v) => setState(() => _period = v)),
                _Chip('Bulan Ini', 'month', _period,
                  (v) => setState(() => _period = v)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _SalesTab(start: _start, end: DateTime.now()),
                _CashTab(start: _start, end: DateTime.now()),
                const _StockTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Export PDF ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final db = ref.read(databaseProvider);
      final end = DateTime.now();

      // Ambil semua data yang dibutuhkan
      final salesData = await db.reportsDao.getDailySalesChart(_start, end);
      final cashData  = await db.reportsDao.getCashReport(_start, end);
      final lowStock  = await db.productsDao.getLowStockProducts();
      final settings     = ref.read(storeSettingsProvider);
      final storeName    = settings.storeName;
      final storeAddress = settings.storeAddress ?? '';

      final pdfBytes = await _buildLaporanPdf(
        storeName: storeName,
        storeAddress: storeAddress,
        periodLabel: _periodLabel,
        salesData: salesData,
        cashData: cashData,
        lowStockProducts: lowStock,
      );

      final now = DateTime.now();
      final filename =
          'laporan_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.pdf';

      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export PDF: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<Uint8List> _buildLaporanPdf({
    required String storeName,
    required String storeAddress,
    required String periodLabel,
    required List<Map<String, dynamic>> salesData,
    required Map<String, double> cashData,
    required List<dynamic> lowStockProducts,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final printDate = DateFormat('dd MMMM yyyy, HH:mm', 'id').format(now);

    const primaryColor = PdfColor.fromInt(0xFF0D9488);
    const successColor = PdfColor.fromInt(0xFF10B981);
    const dangerColor  = PdfColor.fromInt(0xFFEF4444);
    const warningColor = PdfColor.fromInt(0xFFF59E0B);
    const greyColor    = PdfColor.fromInt(0xFF6B7280);
    const lightGrey    = PdfColor.fromInt(0xFFF3F4F6);
    const darkText     = PdfColor.fromInt(0xFF111827);

    // Hitung summary
    final omzet = salesData.fold<double>(
      0, (s, r) => s + (r['omzet'] as num));
    final txCount = salesData.fold<int>(
      0, (s, r) => s + (r['jumlah'] as int));
    final avgTx = txCount > 0 ? omzet / txCount : 0.0;
    final income  = cashData['income'] ?? 0;
    final expense = cashData['expense'] ?? 0;
    final saldo   = cashData['saldo'] ?? 0;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header toko
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(storeName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                    if (storeAddress.isNotEmpty)
                      pw.Text(storeAddress,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: const PdfColor(1, 1, 1, 0.7))),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('LAPORAN KEUANGAN',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                    pw.Text(periodLabel,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: const PdfColor(1, 1, 1, 0.7))),
                    pw.Text('Dicetak: $printDate',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: const PdfColor(1, 1, 1, 0.6))),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
        ],
      ),
      build: (ctx) => [
        // ── Ringkasan Penjualan ──
        _pdfSectionTitle('Ringkasan Penjualan', primaryColor),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _pdfSummaryCard(
            'Total Omzet',
            CurrencyFormatter.format(omzet),
            successColor, lightGrey)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _pdfSummaryCard(
            'Jumlah Transaksi',
            '$txCount transaksi',
            primaryColor, lightGrey)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _pdfSummaryCard(
            'Rata-rata/Transaksi',
            CurrencyFormatter.format(avgTx),
            warningColor, lightGrey)),
        ]),
        pw.SizedBox(height: 16),

        // ── Tabel Detail Penjualan Harian ──
        if (salesData.isNotEmpty) ...[
          _pdfSectionTitle('Detail Penjualan Harian', primaryColor),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: lightGrey, width: 0.5),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryColor),
                children: [
                  _pdfTableCell('Tanggal', isHeader: true),
                  _pdfTableCell('Transaksi', isHeader: true),
                  _pdfTableCell('Omzet', isHeader: true),
                ],
              ),
              // Rows
              ...salesData.map((row) {
                final dateRaw = row['date'];
                String dateStr = '';
                if (dateRaw is String) {
                  try {
                    final dt = DateTime.parse(dateRaw);
                    dateStr = DateFormat('dd MMM yyyy', 'id').format(dt);
                  } catch (_) {
                    dateStr = dateRaw;
                  }
                }
                return pw.TableRow(children: [
                  _pdfTableCell(dateStr),
                  _pdfTableCell('${row['jumlah']}'),
                  _pdfTableCell(
                    CurrencyFormatter.format(
                      (row['omzet'] as num).toDouble())),
                ]);
              }),
              // Total row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: successColor.shade(0.15)),
                children: [
                  _pdfTableCell('TOTAL',
                    bold: true),
                  _pdfTableCell('$txCount',
                    bold: true),
                  _pdfTableCell(
                    CurrencyFormatter.format(omzet),
                    bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
        ],

        // ── Laporan Kas ──
        _pdfSectionTitle('Laporan Kas', primaryColor),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _pdfSummaryCard(
            'Kas Masuk',
            CurrencyFormatter.format(income),
            successColor, lightGrey)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _pdfSummaryCard(
            'Kas Keluar',
            CurrencyFormatter.format(expense),
            dangerColor, lightGrey)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _pdfSummaryCard(
            'Saldo Bersih',
            CurrencyFormatter.format(saldo),
            saldo >= 0 ? successColor : dangerColor,
            lightGrey)),
        ]),
        pw.SizedBox(height: 16),

        // ── Stok Hampir Habis ──
        if (lowStockProducts.isNotEmpty) ...[
          _pdfSectionTitle('Produk Stok Hampir Habis', warningColor),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: lightGrey, width: 0.5),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: warningColor.shade(0.8)),
                children: [
                  _pdfTableCell('Nama Produk', isHeader: true),
                  _pdfTableCell('Stok Saat Ini', isHeader: true),
                  _pdfTableCell('Stok Minimum', isHeader: true),
                  _pdfTableCell('Status', isHeader: true),
                ],
              ),
              ...lowStockProducts.map((p) {
                final isOut = p.stock == 0;
                return pw.TableRow(children: [
                  _pdfTableCell(p.name),
                  _pdfTableCell('${p.stock} ${p.unit}',
                    color: isOut ? dangerColor : warningColor),
                  _pdfTableCell('${p.minStock} ${p.unit}'),
                  _pdfTableCell(
                    isOut ? 'Habis' : 'Hampir Habis',
                    color: isOut ? dangerColor : warningColor,
                    bold: true),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 16),
        ] else ...[
          _pdfSectionTitle('Status Stok', primaryColor),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: successColor.shade(0.1),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(
                color: successColor.shade(0.4), width: 0.5)),
            child: pw.Row(children: [
              pw.Text('✓  ',
                style: pw.TextStyle(
                  color: successColor,
                  fontWeight: pw.FontWeight.bold)),
              pw.Text('Semua stok dalam kondisi aman',
                style: pw.TextStyle(
                  color: successColor,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10)),
            ]),
          ),
        ],

        // Footer
        pw.SizedBox(height: 20),
        pw.Divider(thickness: 0.5, color: greyColor),
        pw.SizedBox(height: 6),
        pw.Text(
          'Laporan ini digenerate otomatis oleh $storeName • $printDate',
          style: const pw.TextStyle(fontSize: 8, color: greyColor),
          textAlign: pw.TextAlign.center),
      ],
    ));

    return doc.save();
  }

  pw.Widget _pdfSectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color.shade(0.15),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border(
          left: pw.BorderSide(color: color, width: 4)),
      ),
      child: pw.Text(title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: color)),
    );
  }

  pw.Widget _pdfSummaryCard(
    String label,
    String value,
    PdfColor color,
    PdfColor bg,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(
          color: color.shade(0.3), width: 0.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
            style: pw.TextStyle(
              fontSize: 8,
              color: const PdfColor.fromInt(0xFF6B7280))),
          pw.SizedBox(height: 4),
          pw.Text(value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color)),
        ],
      ),
    );
  }

  pw.Widget _pdfTableCell(
    String text, {
    bool isHeader = false,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: (isHeader || bold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : color ?? const PdfColor.fromInt(0xFF111827)),
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _Chip(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sel ? Colors.white : null,
          )),
        selected: sel,
        onSelected: (_) => onTap(value),
        selectedColor: AppColors.primary,
      ),
    );
  }
}

// ─── Tab Penjualan ────────────────────────────────────────────────────────────

class _SalesTab extends ConsumerWidget {
  final DateTime start, end;
  const _SalesTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(databaseProvider)
          .reportsDao.getDailySalesChart(start, end),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final omzet = data.fold<double>(
          0, (s, r) => s + (r['omzet'] as num));
        final count = data.fold<int>(
          0, (s, r) => s + (r['jumlah'] as int));
        final avg = count > 0 ? omzet / count : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _InfoCard(
                  title: 'Total Omzet',
                  value: CurrencyFormatter.formatCompact(omzet),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                )),
                const SizedBox(width: 10),
                Expanded(child: _InfoCard(
                  title: 'Transaksi',
                  value: '$count',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                )),
              ]),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Rata-rata per Transaksi',
                value: CurrencyFormatter.format(avg.toDouble()),
                icon: Icons.analytics_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(height: 20),

              if (data.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Grafik Penjualan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: BarChart(BarChartData(
                    barGroups: data.asMap().entries.map((e) =>
                      BarChartGroupData(
                        x: e.key,
                        barRods: [BarChartRodData(
                          toY: (e.value['omzet'] as num).toDouble(),
                          color: AppColors.primary,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        )],
                      )).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 55,
                          getTitlesWidget: (v, _) => Text(
                            CurrencyFormatter.formatCompact(v),
                            style: const TextStyle(fontSize: 9)),
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade200, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                  )),
                ),
                const SizedBox(height: 20),

                // Tabel detail
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Detail Harian',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                ...data.map((row) {
                  final dateRaw = row['date'];
                  String dateStr = '';
                  if (dateRaw is String) {
                    try {
                      final dt = DateTime.parse(dateRaw);
                      dateStr = DateFormat('EEE, dd MMM', 'id').format(dt);
                    } catch (_) {
                      dateStr = dateRaw.toString();
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade100),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(dateStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                      Text('${row['jumlah']} transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500)),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.formatCompact(
                          (row['omzet'] as num).toDouble()),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                    ]),
                  );
                }),
              ] else
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Belum ada data transaksi',
                    style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab Kas ──────────────────────────────────────────────────────────────────

class _CashTab extends ConsumerWidget {
  final DateTime start, end;
  const _CashTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, double>>(
      future: ref.read(databaseProvider)
          .reportsDao.getCashReport(start, end),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        final saldo = d['saldo'] ?? 0;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _InfoCard(
                title: 'Kas Masuk',
                value: CurrencyFormatter.format(d['income']!),
                icon: Icons.arrow_circle_down_rounded,
                color: AppColors.success,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Kas Keluar',
                value: CurrencyFormatter.format(d['expense']!),
                icon: Icons.arrow_circle_up_rounded,
                color: AppColors.danger,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Saldo Bersih',
                value: CurrencyFormatter.format(saldo),
                icon: Icons.account_balance_wallet_rounded,
                color: saldo >= 0 ? AppColors.primary : AppColors.danger,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab Stok ─────────────────────────────────────────────────────────────────

class _StockTab extends ConsumerWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(databaseProvider)
          .productsDao.getLowStockProducts(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                  size: 60, color: AppColors.success),
                const SizedBox(height: 12),
                const Text('Semua stok aman!',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Tidak ada produk yang hampir habis',
                  style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            final isOut = p.stock == 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isOut ? AppColors.danger : AppColors.warning)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOut
                        ? Icons.remove_circle_outline
                        : Icons.warning_amber_rounded,
                    color: isOut ? AppColors.danger : AppColors.warning,
                    size: 20),
                ),
                title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Stok minimum: ${p.minStock} ${p.unit}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.stock} ${p.unit}',
                      style: TextStyle(
                        color: isOut
                            ? AppColors.danger
                            : AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                    Text(
                      isOut ? 'Habis' : 'Hampir habis',
                      style: TextStyle(
                        fontSize: 10,
                        color: isOut
                            ? AppColors.danger
                            : AppColors.warning)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  )),
                const SizedBox(height: 2),
                Text(value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
