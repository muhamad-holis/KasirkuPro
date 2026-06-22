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

/// Satu baris item pada struk.
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
  // PERUBAHAN: diperbesar 12 → 16 agar TOTAL terlihat menonjol seperti
  // pada struk thermal
  static const double _fontSizeXl = 16;

  // Jumlah karakter '=' untuk garis pemisah.
  // Cukup panjang untuk mengisi lebar kertas 80mm; pada 58mm
  // karakter berlebih akan ter-wrap atau terpotong secara alami
  // mengikuti lebar kolom pw.Text.
  static const String _divider = '================================================';

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
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    final pageFormat =
        receiptSize == '80mm' ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

    final totalQty  = items.fold<int>(0, (s, it) => s + it.quantity);

    // PERUBAHAN: subtotal dihitung dari total + discount - tax
    // (formula ChatGPT sebelumnya salah: total - discount - tax)
    // Hanya untuk tampilan, tidak mengubah logika bisnis.
    final subtotal  = total + discount - tax;

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 12),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [

            // ── Logo toko custom ────────────────────────────────────────────
            if (logoImage != null) ...[
              pw.Center(
                child: pw.Image(logoImage,
                    width: 85, height: 85, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 4),
            ],

            // ── Header toko ─────────────────────────────────────────────────
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
              pw.Text('Telp. $storePhone',
                  style: const pw.TextStyle(
                      fontSize: _fontSizeSm, color: PdfColors.black),
                  textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 3),

            // ── PERUBAHAN: garis = seperti struk thermal ─────────────────────
            _hr(),

            // ── Info transaksi 2 kolom ──────────────────────────────────────
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
            pw.SizedBox(height: 2),

            _hr(),

            // ── Daftar barang bernomor ───────────────────────────────────────
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
                            color: PdfColors.black)),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '   ${item.quantity} x ${CurrencyFormatter.format(item.price)}',
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

            // ── PERUBAHAN: Total Item & Total Qty dalam SATU baris ───────────
            // (sebelumnya dua baris terpisah, di struk thermal foto satu baris)
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Total Item : ${items.length}',
                    style: const pw.TextStyle(
                        fontSize: _fontSize, color: PdfColors.black),
                  ),
                ),
                pw.Text(
                  'Total Qty : $totalQty',
                  style: const pw.TextStyle(
                      fontSize: _fontSize, color: PdfColors.black),
                ),
              ],
            ),
            pw.SizedBox(height: 2),

            _hr(),

            // ── PERUBAHAN: baris Subtotal + Diskon + Pajak tanpa prefix +/- ──
            // (formula subtotal diperbaiki: total + discount - tax)
            _infoRow('Subtotal', CurrencyFormatter.format(subtotal)),
            if (discount > 0)
              _infoRow('Diskon',
                  CurrencyFormatter.format(discount)),
            if (tax > 0)
              _infoRow(
                  'Pajak ${taxPercent.toStringAsFixed(0)}%',
                  CurrencyFormatter.format(tax)),
            pw.SizedBox(height: 2),

            _hr(),

            // ── TOTAL menonjol (fontSize 16) ────────────────────────────────
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
            pw.SizedBox(height: 2),

            // PERUBAHAN: separator setelah TOTAL (di foto ada garis setelah TOTAL)
            _hr(),

            // ── Pembayaran ───────────────────────────────────────────────────
            if (amountPaid != null)
              _infoRow('Dibayar', CurrencyFormatter.format(amountPaid)),
            if (change != null && change > 0)
              _infoRow('KEMBALI', CurrencyFormatter.format(change),
                  boldValue: true),
            pw.SizedBox(height: 2),

            // PERUBAHAN: separator setelah KEMBALI
            _hr(),

            // ── Ucapan terima kasih ──────────────────────────────────────────
            pw.SizedBox(height: 2),
            pw.Text(
              storeNote.isNotEmpty
                  ? storeNote
                  : 'Terima kasih telah berbelanja',
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

            // ── Footer permanen KasirKu Pro ──────────────────────────────────
            // Logo & teks di bawah ini SELALU tampil dan TIDAK mengikuti
            // logo custom toko — selalu dari assets/images/app_icon.png.
            pw.SizedBox(height: 6),
            if (footerLogoImage != null) ...[
              pw.Center(
                child: pw.Image(footerLogoImage,
                    width: 100, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 3),
            ],
            // PERUBAHAN: kapital "K" dan "S" sesuai foto
            pw.Text('Link Kritik dan Saran',
                style: const pw.TextStyle(
                    fontSize: _fontSizeSm, color: PdfColors.black),
                textAlign: pw.TextAlign.center),
            // PERUBAHAN: tambah https:// sesuai foto
            pw.Text('https://KasirkuPro.shop/reports',
                style: pw.TextStyle(
                    fontSize: _fontSizeSm,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 4),

            // PERUBAHAN: separator penutup di bagian paling bawah
            _hr(),
          ],
        );
      },
    ));

    return doc.save();
  }

  // ── Helper: garis = (karakter thermal) ──────────────────────────────────
  // Menggunakan karakter '=' agar tampilan PDF mirip struk thermal asli.
  static pw.Widget _hr() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(
          _divider,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
        ),
      );

  // ── Helper: baris info 2 kolom ───────────────────────────────────────────
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
