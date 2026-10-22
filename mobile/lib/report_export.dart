import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _vnd(dynamic value) {
  final n=value is num?value.toDouble():double.tryParse('$value')??0;
  return "${NumberFormat('#,##0','vi').format(n)} VND";
}

/// Export only the authenticated user's entries for the selected month.
Future<void> exportMonthlyPdf({
  required DateTime month,
  required Map<String,dynamic> summary,
  required List<Map<String,dynamic>> transactions,
}) async {
  final key="${month.year}-${month.month.toString().padLeft(2,'0')}";
  final entries=transactions.where((e)=>'${e['occurredOn']}'.startsWith(key)).toList();
  final base=await PdfGoogleFonts.notoSansRegular();
  final bold=await PdfGoogleFonts.notoSansBold();
  final document=pw.Document(theme:pw.ThemeData.withFont(base:base,bold:bold));
  document.addPage(pw.MultiPage(
    pageFormat:PdfPageFormat.a4,
    margin:const pw.EdgeInsets.all(30),
    build:(context)=>[
      pw.Text('MONEYMATE',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold,color:PdfColors.indigo)),
      pw.SizedBox(height:10),
      pw.Text('Báo cáo thu chi - tháng ${month.month}/${month.year}',
        style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold)),
      pw.SizedBox(height:14),
      pw.Text('Thu nhập: ${_vnd(summary['income'])}'),
      pw.Text('Chi tiêu: ${_vnd(summary['expense'])}'),
      pw.Text('Tổng số dư hiện tại: ${_vnd(summary['totalBalance'])}'),
      pw.SizedBox(height:18),
      pw.Text('Chi tiết giao dịch (${entries.length})',
        style:pw.TextStyle(fontWeight:pw.FontWeight.bold,fontSize:13)),
      pw.SizedBox(height:8),
      if (entries.isEmpty) pw.Text('Tháng này chưa có giao dịch.')
      else pw.TableHelper.fromTextArray(
        headers:['Ngày','Loại','Danh mục','Số tiền','Ghi chú'],
        data:entries.map((e)=>[
          '${e['occurredOn']}',
          e['type']=='INCOME'?'Thu':'Chi',
          '${e['category']}',
          _vnd(e['amount']),
          '${e['note']??''}',
        ]).toList(),
        headerStyle:pw.TextStyle(fontWeight:pw.FontWeight.bold),
        headerDecoration:const pw.BoxDecoration(color:PdfColors.grey200),
        cellStyle:const pw.TextStyle(fontSize:9),
        cellPadding:const pw.EdgeInsets.all(5),
      ),
      pw.SizedBox(height:14),
      pw.Text('Dữ liệu cá nhân - chỉ chia sẻ khi cần thiết.',
        style:const pw.TextStyle(fontSize:9,color:PdfColors.grey700)),
    ],
  ));
  await Printing.sharePdf(bytes:await document.save(),filename:'MoneyMate_${key.replaceAll('-','_')}.pdf');
}
