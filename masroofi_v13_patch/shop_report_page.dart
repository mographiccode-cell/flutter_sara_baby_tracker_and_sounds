import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'repository.dart';

class _ReportData {
  final ShopBalance shop;
  final List<LedgerEntry> entries;
  final Map<int, List<PurchaseItemInput>> itemsByEntry;

  const _ReportData({required this.shop, required this.entries, required this.itemsByEntry});
}

class ShopReportPage extends StatefulWidget {
  final int shopId;
  const ShopReportPage({super.key, required this.shopId});

  @override
  State<ShopReportPage> createState() => _ShopReportPageState();
}

class _ShopReportPageState extends State<ShopReportPage> {
  late Future<_ReportData> _dataFuture;
  Uint8List? _cachedPdf;
  bool _saving = false;

  final _date = intl.DateFormat('yyyy/MM/dd', 'en_US');
  final _dateTime = intl.DateFormat('yyyy/MM/dd  HH:mm', 'en_US');
  final _number = intl.NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ReportData> _loadData() async {
    final repo = AppRepository.instance;
    final shop = await repo.getShop(widget.shopId);
    if (shop == null) throw StateError('الحساب غير موجود.');
    final entries = await repo.getShopEntries(widget.shopId);
    final items = <int, List<PurchaseItemInput>>{};
    for (final entry in entries) {
      if (entry.isPurchase) {
        items[entry.id] = await repo.getPurchaseItems(entry.id);
      }
    }
    return _ReportData(shop: shop, entries: entries, itemsByEntry: items);
  }

  String _money(double value) => '${_number.format(value)} ر.س';

  Future<pw.Font> _arabicFont() async {
    const candidates = <String>[
      '/system/fonts/NotoNaskhArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic-Regular.ttf',
      '/system/fonts/NotoSansArabicUI-Regular.ttf',
      '/system/fonts/DroidSansArabic.ttf',
    ];
    for (final path in candidates) {
      try {
        final file = File(path);
        if (await file.exists()) {
          return pw.Font.ttf(ByteData.sublistView(await file.readAsBytes()));
        }
      } catch (_) {}
    }
    return PdfGoogleFonts.notoNaskhArabicRegular();
  }

  Future<Uint8List> _buildPdf(_ReportData data) async {
    if (_cachedPdf != null) return _cachedPdf!;
    final font = await _arabicFont();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      title: 'كشف حساب ${data.shop.name}',
      author: 'مصروفي',
      creator: 'Masroofi 1.3.0',
    );

    final purchases = data.entries.where((e) => e.isPurchase).fold<double>(0, (a, b) => a + b.amount);
    final payments = data.entries.where((e) => !e.isPurchase).fold<double>(0, (a, b) => a + b.amount);

    pw.Widget summaryBox(String title, String value) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );

    final ordered = data.entries.reversed.toList();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 34),
        textDirection: pw.TextDirection.rtl,
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('مصروفي', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('كشف حساب تفصيلي', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(data.shop.name, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if ((data.shop.phone ?? '').trim().isNotEmpty)
            pw.Text('الهاتف: ${data.shop.phone}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('تاريخ إنشاء الكشف: ${_dateTime.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: summaryBox('الرصيد الحالي', _money(data.shop.balance.abs()))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: summaryBox('إجمالي المشتريات', _money(purchases))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: summaryBox('إجمالي الدفعات', _money(payments))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: summaryBox('عدد العمليات', '${data.entries.length}')),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Text(
              data.shop.balance > 0
                  ? 'المبلغ المتبقي عليك: ${_money(data.shop.balance)}'
                  : data.shop.balance < 0
                      ? 'الرصيد لصالحك: ${_money(data.shop.balance.abs())}'
                      : 'الحساب مسدد بالكامل',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('تفاصيل العمليات', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (ordered.isEmpty)
            pw.Text('لا توجد عمليات مسجلة لهذا الحساب.')
          else
            ...ordered.map((entry) {
              final entryItems = data.itemsByEntry[entry.id] ?? const <PurchaseItemInput>[];
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          entry.isPurchase ? 'شراء آجل' : 'دفعة',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Text('${_date.format(entry.date)}  •  ${_money(entry.amount)}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (entry.isPurchase && entryItems.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(3.2),
                          1: pw.FlexColumnWidth(1.0),
                          2: pw.FlexColumnWidth(1.4),
                          3: pw.FlexColumnWidth(1.5),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: ['الصنف', 'الكمية', 'السعر', 'الإجمالي']
                                .map((t) => pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                    ))
                                .toList(),
                          ),
                          ...entryItems.map((item) => pw.TableRow(
                                children: [
                                  item.name,
                                  _number.format(item.quantity),
                                  _money(item.unitPrice),
                                  _money(item.total),
                                ]
                                    .map((t) => pw.Padding(
                                          padding: const pw.EdgeInsets.all(5),
                                          child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)),
                                        ))
                                    .toList(),
                              )),
                        ],
                      ),
                    ],
                    if ((entry.note ?? '').trim().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('ملاحظة: ${entry.note}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 10),
          pw.Text(
            'الإجمالي النهائي: مشتريات ${_money(purchases)} - دفعات ${_money(payments)} = رصيد ${_money(data.shop.balance)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    _cachedPdf = await doc.save();
    return _cachedPdf!;
  }

  String _safeName(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  Future<void> _savePdf(_ReportData data) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _buildPdf(data);
      final filename = 'كشف_${_safeName(data.shop.name)}_${intl.DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ كشف الحساب PDF',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path == null) return;
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف PDF بنجاح.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الكشف: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(data == null ? 'كشف الحساب PDF' : 'كشف ${data.shop.name}'),
            actions: [
              if (data != null)
                IconButton(
                  onPressed: _saving ? null : () => _savePdf(data),
                  tooltip: 'حفظ PDF',
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                ),
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر إنشاء الكشف: ${snapshot.error}', textAlign: TextAlign.center)))
              : data == null
                  ? const Center(child: CircularProgressIndicator())
                  : PdfPreview(
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      allowPrinting: true,
                      allowSharing: true,
                      pdfFileName: 'كشف_${_safeName(data.shop.name)}.pdf',
                      build: (_) => _buildPdf(data),
                      loadingWidget: const Center(child: CircularProgressIndicator()),
                    ),
        );
      },
    );
  }
}
