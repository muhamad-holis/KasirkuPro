#!/bin/bash

# ============================================
# Script: Apply KasirKu Fixes & Push to GitHub
# Jalankan dari folder: ~/kasirku
# ============================================

set -e  # Stop jika ada error

echo "📦 Langkah 1: Cek lokasi script dan repo..."

# Pastikan ada di folder kasirku
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ ERROR: Tidak ada pubspec.yaml di folder ini!"
  echo "   Pindah dulu ke folder repo: cd ~/kasirku"
  exit 1
fi

echo "✅ Folder repo ditemukan: $(pwd)"

# -----------------------------------------------
echo ""
echo "📂 Langkah 2: Cari file ZIP fixes..."

ZIP_FILE=""

# Cek di folder Downloads
if ls ~/storage/downloads/kasirku_fixed_files*.zip 2>/dev/null | head -1 | grep -q zip; then
  ZIP_FILE=$(ls ~/storage/downloads/kasirku_fixed_files*.zip | head -1)
fi

# Cek di folder home
if [ -z "$ZIP_FILE" ] && ls ~/kasirku_fixed_files*.zip 2>/dev/null | head -1 | grep -q zip; then
  ZIP_FILE=$(ls ~/kasirku_fixed_files*.zip | head -1)
fi

# Cek di folder saat ini
if [ -z "$ZIP_FILE" ] && ls kasirku_fixed_files*.zip 2>/dev/null | head -1 | grep -q zip; then
  ZIP_FILE=$(ls kasirku_fixed_files*.zip | head -1)
fi

if [ -z "$ZIP_FILE" ]; then
  echo "❌ ERROR: File kasirku_fixed_files.zip tidak ditemukan!"
  echo ""
  echo "   Pastikan kamu sudah download file ZIP dari Claude."
  echo "   Lalu pindahkan ke folder Downloads atau ~/kasirku"
  echo ""
  echo "   Contoh manual jika file ada di Downloads:"
  echo "   cp ~/storage/downloads/kasirku_fixed_files.zip ~/kasirku/"
  exit 1
fi

echo "✅ ZIP ditemukan: $ZIP_FILE"

# -----------------------------------------------
echo ""
echo "📤 Langkah 3: Extract file fixes..."

# Extract ke folder temp
TEMP_DIR=$(mktemp -d)
unzip -o "$ZIP_FILE" -d "$TEMP_DIR"

echo "✅ Extract selesai ke: $TEMP_DIR"

# -----------------------------------------------
echo ""
echo "🔄 Langkah 4: Copy file ke repo..."

# Copy masing-masing file
cp "$TEMP_DIR/lib/presentation/screens/kasir/kasir_screen.dart" \
   "lib/presentation/screens/kasir/kasir_screen.dart"
echo "  ✅ kasir_screen.dart"

cp "$TEMP_DIR/lib/data/database/app_database.dart" \
   "lib/data/database/app_database.dart"
echo "  ✅ app_database.dart"

cp "$TEMP_DIR/lib/data/database/daos/products_dao.dart" \
   "lib/data/database/daos/products_dao.dart"
echo "  ✅ products_dao.dart"

cp "$TEMP_DIR/pubspec.yaml" \
   "pubspec.yaml"
echo "  ✅ pubspec.yaml"

# Hapus temp folder
rm -rf "$TEMP_DIR"

# -----------------------------------------------
echo ""
echo "🔍 Langkah 5: Verifikasi perubahan..."

# Cek fix 1
if grep -q "transactionId: 0," lib/presentation/screens/kasir/kasir_screen.dart; then
  echo "  ✅ Fix 1: Value<T> wrapper sudah dihapus di kasir_screen.dart"
else
  echo "  ⚠️  Fix 1: Perlu dicek manual kasir_screen.dart"
fi

# Cek fix 2
if grep -q "name: 'kasirku'" lib/data/database/app_database.dart; then
  echo "  ✅ Fix 2: name parameter sudah ada di app_database.dart"
else
  echo "  ⚠️  Fix 2: Perlu dicek manual app_database.dart"
fi

# Cek fix 3
if grep -q "isSmallerOrEqualValue" lib/data/database/daos/products_dao.dart; then
  echo "  ✅ Fix 3: isSmallerOrEqualValue sudah ada di products_dao.dart"
else
  echo "  ⚠️  Fix 3: Perlu dicek manual products_dao.dart"
fi

# Cek fix 4
if grep -q "drift: \^2.19.0" pubspec.yaml; then
  echo "  ✅ Fix 4: drift versi 2.19.0 sudah di pubspec.yaml"
else
  echo "  ⚠️  Fix 4: Perlu dicek manual pubspec.yaml"
fi

# -----------------------------------------------
echo ""
echo "📝 Langkah 6: Git add & commit..."

git add \
  lib/presentation/screens/kasir/kasir_screen.dart \
  lib/data/database/app_database.dart \
  lib/data/database/daos/products_dao.dart \
  pubspec.yaml

git commit -m "fix: resolve drift API compatibility issues

- Remove Value<T> wrappers from TransactionItemsCompanion.insert()
- Add name parameter to driftDatabase() in app_database.dart
- Replace lessOrEqualValue() with isSmallerOrEqualValue() in products_dao.dart
- Bump drift from ^2.18.0 to ^2.19.0 in pubspec.yaml"

echo "✅ Commit berhasil!"

# -----------------------------------------------
echo ""
echo "🚀 Langkah 7: Push ke GitHub..."

git push origin main

echo ""
echo "============================================"
echo "🎉 SELESAI! Semua fix berhasil di-push ke GitHub."
echo "   GitHub Actions akan otomatis build APK sekarang."
echo "============================================"
