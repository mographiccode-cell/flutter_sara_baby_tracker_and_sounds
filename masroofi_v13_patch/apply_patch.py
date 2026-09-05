from pathlib import Path
root = Path('masroofi')
pubspec = root / 'pubspec.yaml'
s = pubspec.read_text()
s = s.replace('version: 1.2.0+3', 'version: 1.3.0+4')
s = s.replace('  file_picker: ^12.2.0\n', '  file_picker: ^12.2.0\n  pdf: ^3.11.3\n  printing: ^5.14.2\n')
pubspec.write_text(s)
repo = root / 'lib/repository.dart'
s = repo.read_text()
needle = '  Future<List<PurchaseItemInput>> getLastPurchaseItems(int shopId) async {\n'
method = '''  Future<List<PurchaseItemInput>> getPurchaseItems(int entryId) async {\n    final db = await AppDatabase.instance.database;\n    final rows = await db.query('purchase_items', columns: ['name', 'quantity', 'unit_price'], where: 'entry_id = ?', whereArgs: [entryId], orderBy: 'id ASC');\n    return rows.map((r) => PurchaseItemInput(name: (r['name'] as String?) ?? '', quantity: (r['quantity'] as num?)?.toDouble() ?? 1.0, unitPrice: (r['unit_price'] as num?)?.toDouble() ?? 0.0)).where((i) => i.name.trim().isNotEmpty).toList();\n  }\n\n'''
if 'getPurchaseItems(int entryId)' not in s: s = s.replace(needle, method + needle)
repo.write_text(s)
screens = root / 'lib/screens.dart'
s = screens.read_text()
if "import 'shop_report_page.dart';" not in s: s = s.replace("import 'repository.dart';\n", "import 'repository.dart';\nimport 'shop_report_page.dart';\n")
needle = "                const SizedBox(height: 24),\n                const _SectionTitle(title: 'سجل الحساب'),"
insert = "                const SizedBox(height: 12),\n                OutlinedButton.icon(onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => ShopReportPage(shopId: shop.id))), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('كشف تفصيلي PDF'))),\n                const SizedBox(height: 24),\n                const _SectionTitle(title: 'سجل الحساب'),"
if 'ShopReportPage(shopId: shop.id)' not in s: s = s.replace(needle, insert, 1)
screens.write_text(s)
