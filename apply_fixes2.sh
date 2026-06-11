#!/bin/bash
set -e

echo "📦 Apply KasirKu Fixes Batch 2"

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Pindah dulu: cd ~/kasirku"
  exit 1
fi

# Cari ZIP
ZIP_FILE=""
for loc in ~/storage/downloads/kasirku_fixes2.zip ~/kasirku_fixes2.zip kasirku_fixes2.zip; do
  [ -f "$loc" ] && ZIP_FILE="$loc" && break
done

if [ -z "$ZIP_FILE" ]; then
  echo "❌ kasirku_fixes2.zip tidak ditemukan!"
  echo "   Pindahkan ke ~/kasirku/ atau ~/storage/downloads/"
  exit 1
fi

echo "✅ ZIP: $ZIP_FILE"

TEMP=$(mktemp -d)
unzip -o "$ZIP_FILE" -d "$TEMP"

cp "$TEMP/lib/data/database/tables/sync_queue_table.dart" lib/data/database/tables/sync_queue_table.dart
echo "  ✅ sync_queue_table.dart"

cp "$TEMP/lib/data/database/app_database.dart" lib/data/database/app_database.dart
echo "  ✅ app_database.dart"

cp "$TEMP/lib/data/database/daos/products_dao.dart" lib/data/database/daos/products_dao.dart
echo "  ✅ products_dao.dart"

cp "$TEMP/lib/presentation/navigation/app_router.dart" lib/presentation/navigation/app_router.dart
echo "  ✅ app_router.dart"

rm -rf "$TEMP"

echo ""
echo "🔍 Verifikasi..."
grep -q "syncTableName" lib/data/database/tables/sync_queue_table.dart && echo "  ✅ Fix 1: syncTableName OK" || echo "  ⚠️ Fix 1 gagal"
grep -q "DriftNativeOptions" lib/data/database/app_database.dart && echo "  ✅ Fix 2: DriftNativeOptions OK" || echo "  ⚠️ Fix 2 gagal"
grep -q "isSmallerOrEqual(t.minStock)" lib/data/database/daos/products_dao.dart && echo "  ✅ Fix 3: isSmallerOrEqual OK" || echo "  ⚠️ Fix 3 gagal"

echo ""
echo "📝 Git commit & push..."
git add \
  lib/data/database/tables/sync_queue_table.dart \
  lib/data/database/app_database.dart \
  lib/data/database/daos/products_dao.dart \
  lib/presentation/navigation/app_router.dart

git commit -m "fix: resolve remaining drift & AppColors build errors

- Rename tableName column to syncTableName in SyncQueue table
- Fix native: true -> native: DriftNativeOptions() in app_database.dart
- Fix isSmallerOrEqualValue(column) -> isSmallerOrEqual(column) in products_dao.dart
- Fix AppColors scope in app_router.dart _NavItem widget"

git push origin main

echo ""
echo "🎉 SELESAI! Push berhasil."
