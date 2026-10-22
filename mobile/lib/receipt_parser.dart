class ReceiptData {
  final String rawText;
  final String merchant;
  final int? amount;
  final bool hasTotalLabel;

  const ReceiptData({
    required this.rawText,
    required this.merchant,
    required this.amount,
    required this.hasTotalLabel,
  });
}

String _fold(String value) {
  const accents = [
    'àáạảãâầấậẩẫăằắặẳẵ', 'èéẹẻẽêềếệểễ', 'ìíịỉĩ',
    'òóọỏõôồốộổỗơờớợởỡ', 'ùúụủũưừứựửữ', 'ỳýỵỷỹ', 'đ'
  ];
  const ascii = ['a','e','i','o','u','y','d'];
  var result = value.toLowerCase();
  for (var i=0; i<accents.length; i++) {
    for (final rune in accents[i].runes) {
      result = result.replaceAll(String.fromCharCode(rune), ascii[i]);
    }
  }
  return result;
}

final _money = RegExp(
  r'(?<!\d)(\d{1,3}(?:[.,\s]\d{3}){1,3}|\d{4,10})(?:[.,]\d{2})?\s*(?:₫|đ|vnd)?(?!\d)',
  caseSensitive: false,
);

int? _amount(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'\s*(?:₫|đ|vnd)\s*$',caseSensitive:false),'');
  if (RegExp(r'[.,]\d{2}$').hasMatch(text)) {
    final i = text.lastIndexOf(RegExp(r'[.,]'));
    if (i>0 && (text.substring(0,i).replaceAll(RegExp(r'\D'),'').length>3
        || text.substring(0,i).contains(RegExp(r'[.,]')))) {
      text=text.substring(0,i);
    }
  }
  final n=int.tryParse(text.replaceAll(RegExp(r'\D'),''));
  if (n==null || n<1000 || n>2000000000) return null;
  return n;
}

/// OCR may be inaccurate; this proposal is never persisted automatically.
ReceiptData parseReceiptText(String rawText) {
  final lines=rawText.split(RegExp(r'\r?\n')).map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList();
  const markers=['tong tien','tong cong','thanh toan','phai tra','grand total',
    'total amount','total','cong tien','thanh tien'];
  int? chosen;
  var score=-1;
  var labelled=false;
  for (final line in lines) {
    final fold=_fold(line);
    if (RegExp(r'(ma so thue|mst|dien thoai|so hoa don|invoice no|ma giao dich|ngay lap|ngay:|date:)')
        .hasMatch(fold)) continue;
    final total=markers.any(fold.contains);
    for (final m in _money.allMatches(line)) {
      final value=_amount(m.group(0)!);
      if (value==null) continue;
      final rank=(total?100:0)+(fold.contains('vnd')||line.contains('₫')?10:0)
        +(value>=10000?1:0);
      if (rank>score || (rank==score && value>(chosen??0))) {
        score=rank;chosen=value;labelled=total;
      }
    }
  }
  final name=lines.isEmpty?'':(lines.first.length<=70?lines.first:lines.first.substring(0,70));
  return ReceiptData(rawText:rawText,merchant:name,amount:chosen,hasTotalLabel:labelled);
}
