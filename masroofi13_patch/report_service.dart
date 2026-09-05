import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';
import 'repository.dart';

class ReportService {
  static Future<Uint8List> buildShopStatement(ShopBalance shop, List<LedgerEntry> entries) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final doc = pw.Document();
    final repo = AppRepository.instance;
    final rows = <pw.Widget>[];
    double purchases = 0, payments = 0;
    for (final e in entries.reversed) {
      if (e.isPurchase) purchases += e.amount; else payments += e.amount;
      final items = e.isPurchase ? await repo.getPurchaseItemsForEntry(e.id) : <Map<String,Object?>>[];
      rows.add(pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 7), decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(_date(e.date), style: pw.TextStyle(font: font, fontSize: 9)), pw.Text(e.isPurchase ? 'مشتريات  ${_money(e.amount)}' : 'دفعة  ${_money(e.amount)}', style: pw.TextStyle(font: font, fontSize: 10), textDirection: pw.TextDirection.rtl)]),
        if (items.isNotEmpty) ...items.map((i) { final q=(i['quantity'] as num?)?.toDouble() ?? 1; final price=(i['unit_price'] as num?)?.toDouble() ?? 0; return pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('${i['name']}   × ${_num(q)}   ${_money(price)}   = ${_money(q*price)}', style: pw.TextStyle(font: font, fontSize: 8), textDirection: pw.TextDirection.rtl)); }),
        if ((e.note ?? '').trim().isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('ملاحظة: ${e.note}', style: pw.TextStyle(font: font, fontSize: 8), textDirection: pw.TextDirection.rtl)),
      ])));
    }
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), theme: pw.ThemeData.withFont(base: font, bold: font), textDirection: pw.TextDirection.rtl,
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [pw.Text('مصروفي', style: pw.TextStyle(font: font, fontSize: 18), textAlign: pw.TextAlign.right), pw.Text('كشف حساب تفصيلي', style: pw.TextStyle(font: font, fontSize: 15), textAlign: pw.TextAlign.right), pw.SizedBox(height: 6), pw.Divider()]),
      footer: (c) => pw.Text('صفحة ${c.pageNumber} من ${c.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
      build: (_) => [pw.Text('البقالة / الشخص: ${shop.name}', style: pw.TextStyle(font: font, fontSize: 14)), if ((shop.phone ?? '').isNotEmpty) pw.Text('الهاتف: ${shop.phone}', style: pw.TextStyle(font: font, fontSize: 9)), pw.SizedBox(height: 10),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [pw.Text('إجمالي المشتريات: ${_money(purchases)}', style: pw.TextStyle(font: font, fontSize: 10)), pw.Text('إجمالي الدفعات: ${_money(payments)}', style: pw.TextStyle(font: font, fontSize: 10)), pw.Text(shop.balance > 0 ? 'المتبقي عليك: ${_money(shop.balance)}' : shop.balance < 0 ? 'رصيد لك: ${_money(shop.balance.abs())}' : 'الحساب مسدد بالكامل', style: pw.TextStyle(font: font, fontSize: 12))])),
        pw.SizedBox(height: 12), pw.Text('تفاصيل العمليات', style: pw.TextStyle(font: font, fontSize: 12)), ...rows, pw.SizedBox(height: 12), pw.Text('عدد العمليات: ${entries.length}', style: pw.TextStyle(font: font, fontSize: 9))]));
    return doc.save();
  }
  static Future<void> shareShopStatement(ShopBalance shop, List<LedgerEntry> entries) async { final bytes = await buildShopStatement(shop, entries); final safe = shop.name.replaceAll(RegExp(r'[^\w\u0600-\u06FF-]+'), '_'); await Printing.sharePdf(bytes: bytes, filename: 'كشف_حساب_$safe.pdf'); }
  static String _money(double v) => '${v.toStringAsFixed(v.truncateToDouble()==v ? 0 : 2)} ر.س';
  static String _num(double v) => v.toStringAsFixed(v.truncateToDouble()==v ? 0 : 2);
  static String _date(DateTime d) => '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}';
}
