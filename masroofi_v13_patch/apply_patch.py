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
method = '''  Future<List<PurchaseItemInput>> getPurchaseItems(int entryId) async {\n    final db = await AppDatabase.instance.database;\n    final rows = await db.query(\n      'purchase_items',\n      columns: ['name', 'quantity', 'unit_price'],\n      where: 'entry_id = ?',\n      whereArgs: [entryId],\n      orderBy: 'id ASC',\n    );\n    return rows\n        .map((r) => PurchaseItemInput(\n              name: (r['name'] as String?) ?? '',\n              quantity: (r['quantity'] as num?)?.toDouble() ?? 1.0,\n              unitPrice: (r['unit_price'] as num?)?.toDouble() ?? 0.0,\n            ))\n        .where((i) => i.name.trim().isNotEmpty)\n        .toList();\n  }\n\n'''
if 'getPurchaseItems(int entryId)' not in s:
    s = s.replace(needle, method + needle)
repo.write_text(s)

screens = root / 'lib/screens.dart'
s = screens.read_text()
if "import 'shop_report_page.dart';" not in s:
    s = s.replace("import 'repository.dart';\n", "import 'repository.dart';\nimport 'shop_report_page.dart';\n")
needle = """                const SizedBox(height: 24),\n                const _SectionTitle(title: 'سجل الحساب'),\n"""
insert = """                const SizedBox(height: 12),\n                OutlinedButton.icon(\n                  onPressed: () {\n                    Navigator.push<void>(\n                      context,\n                      MaterialPageRoute(builder: (_) => ShopReportPage(shopId: shop.id)),\n                    );\n                  },\n                  icon: const Icon(Icons.picture_as_pdf_rounded),\n                  label: const Padding(\n                    padding: EdgeInsets.symmetric(vertical: 12),\n                    child: Text('كشف تفصيلي PDF'),\n                  ),\n                ),\n                const SizedBox(height: 24),\n                const _SectionTitle(title: 'سجل الحساب'),\n"""
if 'ShopReportPage(shopId: shop.id)' not in s:
    s = s.replace(needle, insert, 1)
screens.write_text(s)
