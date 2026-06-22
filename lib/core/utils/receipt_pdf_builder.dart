// lib/core/utils/receipt_pdf_builder.dart
//
// Generator tampilan PDF struk KasirKu Pro.
// Dipakai bersama oleh halaman Kasir (struk transaksi baru) dan halaman
// Riwayat (cetak ulang struk) supaya tampilan struk selalu konsisten.
//
// PENTING: file ini HANYA mengatur tampilan/layout PDF (monokrom, hemat
// tinta, rapi untuk thermal 58mm/80mm maupun export biasa).
// TIDAK ADA perhitungan bisnis di sini — subtotal/diskon/pajak/total/kembali
// semuanya dikirim oleh pemanggil apa adanya, tidak dihitung ulang.

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'currency.dart';

/// Satu baris item pada struk (hasil mapping dari cart kasir / dari item
/// transaksi tersimpan di database — lihat pemanggil).
class ReceiptPdfItem {
  final String name;
  final int quantity;
  final double price;
  final double subtotal;

  const ReceiptPdfItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });
}

class ReceiptPdfBuilder {
  ReceiptPdfBuilder._();

  static const double _fontSize   = 8;
  static const double _fontSizeSm = 7;
  static const double _fontSizeLg = 10;
  static const double _fontSizeXl = 12;

  /// Bangun dokumen PDF struk dan kembalikan sebagai bytes siap simpan/share.
  ///
  /// [logoImage]       : logo toko custom (mengikuti Pengaturan > Struk).
  /// [footerLogoImage] : logo KasirKu Pro PERMANEN di footer — selalu dari
  ///                     assets/images/app_icon.png, tidak mengikuti logo
  ///                     custom toko.
  static Future<Uint8List> build({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String storeNote,
    required String invoiceNumber,
    required DateTime date,
    required String paymentMethodLabel,
    String? kasirName,
    String? customerName,
    required List<ReceiptPdfItem> items,
    double discount = 0,
    double tax = 0,
    double taxPercent = 0,
    required double total,
    double? amountPaid,
    double? change,
    String receiptSize = '58mm',
    pw.MemoryImage? logoImage,
    pw.MemoryImage? footerLogoImage,
  }) async {
    final doc = pw.Document();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    // PERUBAHAN #12 (Responsive): ukuran halaman mengikuti pengaturan ukuran
    // kertas struk (58mm/80mm) — sebelumnya selalu hard-coded roll57.
    // Karena seluruh layout di bawah memakai Row + Expanded (bukan lebar
    // karakter tetap), tampilan tetap rapi pula bila suatu saat dirender
    // pada halaman yang lebih lebar (mis. A4).
    final pageFormat =
        receiptSize == '80mm' ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

    final totalQty = items.fold<int>(0, (sum, it) => sum + it.quantity);

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      // PERUBAHAN #1 & #11: margin atas dipersempit (10 -> 6) supaya logo
      // tidak menggantung dengan ruang kosong besar di atas, struk jadi
      // lebih padat secara keseluruhan.
      margin: const pw.EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 12),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── PERUBAHAN #1: logo toko custom, diperbesar ~35% (60->110) ──
            if (logoImage != null) ...[
              pw.Center(
                child: pw.Image(logoImage,
                    width: 110, height: 110, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 4),
            ],

            // ── Header toko ────────────────────────────────────────────────
            pw.Text(storeName,
                style: pw.TextStyle(
                    fontSize: _fontSizeLg + 2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black),
                textAlign: pw.TextAlign.center),
            if (storeAddress.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(storeAddress,
                  style: const pw.TextStyle(
                      fontSize: _fontSizeSm, color: PdfColors.black),
                  textAlign: pw.TextAlign.center),
            ],
            if (storePhone.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Text('Telp: $storePhone',
                  style: const pw.TextStyle(
                      fontSize: _fontSizeSm, color: PdfColors.black),
                  textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 5),

            // ── PERUBAHAN #2: garis pemisah PENUH ujung ke ujung ────────────
            // (sebelumnya string dash pendek '---' yang terlihat menggantung
            // di tengah, terutama pada kertas 80mm)
            _hr(),

            // ── PERUBAHAN #3 & #4: info transaksi 2 kolom (label kiri rata,
            // nilai kanan rata, selalu sejajar via Expanded) + baris
            // Kasir & Pelanggan ───────────────────────────────────────────
            _infoRow('No Invoice', invoiceNumber),
            _infoRow('Tanggal', dateStr),
            _infoRow('Metode', paymentMethodLabel),
            if (kasirName != null && kasirName.isNotEmpty)
              _infoRow('Kasir', kasirName),
            _infoRow(
              'Pelanggan',
              (customerName != null && customerName.isNotEmpty)
                  ? customerName
                  : 'Umum',
            ),

            _hr(),

            // ── PERUBAHAN #5: daftar barang dengan nomor urut, nama barang
            // font normal (tidak full-bold) — hanya sedikit lebih tegas
            // karena ukurannya satu step lebih besar dari baris qty x harga.
            ...items.asMap().entries.map((entry) {
              final number = entry.key + 1;
              final item   = entry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$number. ${item.name}',
                        style: const pw.TextStyle(
                            fontSize: _fontSize,
                            fontWeight: pw.FontWeight.normal,
                            color: PdfColors.black)),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '    ${item.quantity} x ${CurrencyFormatter.format(item.price)}',
                            style: const pw.TextStyle(
                                fontSize: _fontSizeSm,
                                color: PdfColors.black),
                          ),
                        ),
                        pw.Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: pw.TextStyle(
                              fontSize: _fontSize,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            _hr(),

            // ── PERUBAHAN #6: ringkasan total item & qty sebelum subtotal ───
            _infoRow('Total Item', '${items.length}'),
            _infoRow('Total Qty', '$totalQty'),

            if (discount > 0)
              _infoRow('Diskon', '- ${CurrencyFormatter.format(discount)}'),
            if (tax > 0)
              _infoRow('Pajak (${taxPercent.toStringAsFixed(0)}%)',
                  '+ ${CurrencyFormatter.format(tax)}'),

            _hr(thickness: 1.1),

            // ── PERUBAHAN #7: TOTAL dibuat paling menonjol (font besar+bold) ─
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(
                        fontSize: _fontSizeXl,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.Text(CurrencyFormatter.format(total),
                    style: pw.TextStyle(
                        fontSize: _fontSizeXl,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
              ],
            ),
            pw.SizedBox(height: 4),

            // ── PERUBAHAN #8: info pembayaran — KEMBALI ditebalkan ──────────
            if (amountPaid != null)
              _infoRow('Dibayar', CurrencyFormatter.format(amountPaid)),
            if (change != null && change > 0)
              _infoRow('KEMBALI', CurrencyFormatter.format(change),
                  boldValue: true),

            pw.SizedBox(height: 6),
            _hr(),

            // ── PERUBAHAN #9: ucapan terima kasih, rata tengah ──────────────
            pw.SizedBox(height: 2),
            pw.Text(
              storeNote.isNotEmpty
                  ? storeNote
                  : 'Terima kasih telah berbelanja!',
              style: pw.TextStyle(
                  fontSize: _fontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text('Simpan struk ini sebagai bukti pembelian',
                style: const pw.TextStyle(
                    fontSize: _fontSizeSm, color: PdfColors.black),
                textAlign: pw.TextAlign.center),

            // ── PERUBAHAN #10: footer permanen KasirKu Pro ──────────────────
            // Logo & teks di bawah ini SELALU tampil dan TIDAK mengikuti
            // logo custom toko — selalu dari assets/images/app_icon.png.
            pw.SizedBox(height: 10),
            if (footerLogoImage != null) ...[
              pw.Center(
                // Lebar 100 tanpa height tetap — proporsional mengikuti rasio
                // asli logo (misal 3264x1207 → ~2.7:1, tinggi otomatis ~37pt)
                child: pw.Image(footerLogoImage,
                    width: 100, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 3),
            ],
            pw.Text('Link kritik dan saran',
                style: const pw.TextStyle(
                    fontSize: _fontSizeSm, color: PdfColors.black),
                textAlign: pw.TextAlign.center),
            pw.Text('KasirkuPro.shop/reports',
                style: pw.TextStyle(
                    fontSize: _fontSizeSm,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black),
                textAlign: pw.TextAlign.center),
          ],
        );
      },
    ));

    return doc.save();
  }

  // ── Helper: garis pemisah PENUH dari ujung kiri ke ujung kanan ───────────
  // (Container full-width, bukan string dash, supaya selalu menyambung
  // sampai tepi struk pada ukuran kertas berapa pun.)
  static pw.Widget _hr({double thickness = 0.6}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Container(height: thickness, color: PdfColors.black),
      );

  // ── Helper: baris info 2 kolom — label rata kiri, nilai rata kanan,
  // selalu sejajar karena label pakai lebar tetap + nilai pakai Expanded. ──
  static pw.Widget _infoRow(String label, String value,
          {bool boldValue = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 62,
              child: pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: _fontSize, color: PdfColors.black)),
            ),
            pw.Text(': ',
                style: const pw.TextStyle(
                    fontSize: _fontSize, color: PdfColors.black)),
            pw.Expanded(
              child: pw.Text(value,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: _fontSize,
                      fontWeight: boldValue
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: PdfColors.black)),
            ),
          ],
        ),
      );
}
