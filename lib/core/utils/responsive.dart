import 'package:flutter/material.dart';

/// FITUR TABLET: Helper untuk membuat layout adaptif antara HP dan Tablet.
///
/// Breakpoint yang dipakai:
/// - < 600   : HP (mobile)
/// - 600-900 : Tablet kecil / HP landscape
/// - > 900   : Tablet besar / landscape
class Responsive {
  Responsive._();

  static const double _tabletBreakpoint = 600;
  static const double _largeTabletBreakpoint = 900;

  /// True jika lebar layar tergolong tablet (>= 600dp), baik potrait
  /// maupun landscape. Dipakai untuk keputusan layout umum.
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= _tabletBreakpoint;
  }

  /// True hanya jika tablet DAN dalam orientasi landscape.
  /// Dipakai khusus untuk keputusan: tampilkan sidebar (NavigationRail)
  /// alih-alih bottom navigation bar.
  static bool isTabletLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    return isTablet(context) && isLandscape;
  }

  /// Jumlah kolom grid yang disarankan berdasarkan lebar layar saat ini.
  /// Dipakai di GridView produk, kategori, dan menu grid lainnya.
  static int gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= _largeTabletBreakpoint) return 6;
    if (width >= _tabletBreakpoint) return 4;
    return 3; // default HP, sama seperti sebelumnya
  }

  /// Khusus untuk grid yang lebih padat (mis. grid produk kecil),
  /// memberi 1 kolom tambahan dibanding gridColumns standar.
  static int gridColumnsDense(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= _largeTabletBreakpoint) return 7;
    if (width >= _tabletBreakpoint) return 5;
    return 3;
  }
}
