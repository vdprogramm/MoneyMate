import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_scanner.dart';
import 'report_export.dart';
import 'offline_queue.dart';

const brand = Color(0xFF5165E8);
const dark = Color(0xFF172338);
const green = Color(0xFF10A68A);
const red = Color(0xFFED6772);
const muted = Color(0xFF79869A);
const expenseCategories = ['Ăn uống', 'Mua sắm', 'Di chuyển', 'Nhà ở', 'Hóa đơn', 'Giải trí', 'Sức khỏe', 'Giáo dục', 'Khác'];
const incomeCategories = ['Lương', 'Thưởng', 'Đầu tư', 'Quà tặng', 'Khác'];

String money(dynamic value) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return '${NumberFormat('#,##0', 'vi').format(amount)} ₫';
}
double amountOf(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Widget section(String title) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 10),
  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark)),
);
Widget infoCard({required Widget child, EdgeInsets? padding}) => Container(
  width: double.infinity,
  padding: padding ?? const EdgeInsets.all(16),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
  child: child,
);
Widget loadError(Object error, VoidCallback retry) => Center(child: Padding(
  padding: const EdgeInsets.all(20),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off, size: 40, color: muted), const SizedBox(height: 12),
    Text(apiError(error), textAlign: TextAlign.center), const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
  ]),
));

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override ConsumerState<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends ConsumerState<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false;
  @override void dispose() { name.dispose();email.dispose();password.dispose();super.dispose(); }
  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (register) {
        await ref.read(authProvider.notifier).register(name.text, email.text, password.text);
      } else {
        await ref.read(authProvider.notifier).login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(26), child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.account_balance_wallet_rounded, color: brand, size: 62),
        const SizedBox(height: 14), const Text('MoneyMate', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, color: brand, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), const Text('Quản lý tài chính thông minh', textAlign: TextAlign.center,
          style: TextStyle(color: muted)), const SizedBox(height: 30),
        if (register) ...[
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (x) => (x?.trim().length ?? 0) < 2 ? 'Nhập ít nhất 2 ký tự' : null),
          const SizedBox(height: 12),
        ],
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (x) => (x == null || !x.contains('@')) ? 'Email không hợp lệ' : null),
        const SizedBox(height: 12),
        TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu'),
          validator: (x) => (x?.length ?? 0) < (register ? 10 : 1) ? 'Mật khẩu không hợp lệ' : null),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : submit, child: Padding(
          padding: const EdgeInsets.all(12), child: Text(busy ? 'Đang xử lý...' : (register ? 'Tạo tài khoản' : 'Đăng nhập')),
        )), const SizedBox(height: 12),
        TextButton(onPressed: busy ? null : () => setState(() => register = !register),
          child: Text(register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký')),
      ],
    )),
  ))));
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override ConsumerState<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  int index=0;
  bool syncing=false;
  int pendingCount=0;
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_)=>syncPending());
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)syncPending();
  }
  Future<void> syncPending()async{
    if(syncing)return;
    final email=ref.read(authProvider).userEmail;
    if(email==null || email.isEmpty)return;
    if(mounted)setState(()=>syncing=true);
    try{
      await OfflineQueue.sync(email,ref.read(apiProvider));
      refreshData(ref);
    }catch(_){
      // Retain local drafts for a subsequent retry.
    }finally{
      final pending=await OfflineQueue.count(email);
      if(mounted)setState((){syncing=false;pendingCount=pending;});
    }
  }
  @override Widget build(BuildContext context) {
    const titles = ['Tổng quan', 'Giao dịch', 'Ngân sách', 'Thống kê', 'Cá nhân'];
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MoneyMate', style: TextStyle(fontSize: 13, color: brand, fontWeight: FontWeight.bold)),
        Text(titles[index], style: const TextStyle(color: dark, fontWeight: FontWeight.bold, fontSize: 23)),
      ]), toolbarHeight:72,actions:[
        if(pendingCount>0) Center(child:Text(pendingCount.toString()+' chờ gửi',
          style:const TextStyle(fontSize:12,color:red))),
        IconButton(onPressed:syncing?null:syncPending,tooltip:'Đồng bộ offline',
          icon:Icon(syncing?Icons.hourglass_top:Icons.sync)),
        IconButton(onPressed:()=>refreshData(ref),icon:const Icon(Icons.refresh))]),
      body: IndexedStack(index: index, children: const [DashboardTab(), TransactionTab(), BudgetTab(), StatisticsTab(), ProfileTab()]),
      floatingActionButton: index == 0 || index == 1 ? FloatingActionButton.extended(
        backgroundColor: brand, foregroundColor: Colors.white, onPressed: () => showTransactionForm(context, ref),
        icon: const Icon(Icons.add), label: const Text('Giao dịch'),
      ) : null,
      bottomNavigationBar: NavigationBar(height: 75, selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Giao dịch'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Ngân sách'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Thống kê'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
        ]),
    );
  }
}

class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(monthProvider);
    return Row(children: [
      IconButton(onPressed: () => ref.read(monthProvider.notifier).state = DateTime(date.year, date.month - 1), icon: const Icon(Icons.chevron_left)),
      Text('Tháng ${date.month}/${date.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
      IconButton(onPressed: () => ref.read(monthProvider.notifier).state = DateTime(date.year, date.month + 1), icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(summaryProvider);
    return RefreshIndicator(onRefresh: () async { refreshData(ref); await ref.read(summaryProvider.future); },
      child: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => loadError(e, () => ref.invalidate(summaryProvider)),
        data: (data) {
          final recent = (data['recentTransactions'] as List? ?? []);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            const MonthPicker(),
            Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tổng số dư', style: TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 10),
                FittedBox(fit: BoxFit.scaleDown, child: Text(money(data['totalBalance']), style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.bold))),
                const SizedBox(height: 7), const Text('Trong tất cả các ví', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            const SizedBox(height: 12), Row(children: [
              Expanded(child: infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Thu nhập', style: TextStyle(color: muted)), const SizedBox(height: 8),
                FittedBox(child: Text(money(data['income']), style: const TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 18))),
              ]))), const SizedBox(width: 9),
              Expanded(child: infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Chi tiêu', style: TextStyle(color: muted)), const SizedBox(height: 8),
                FittedBox(child: Text(money(data['expense']), style: const TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 18))),
              ]))),
            ]),
            section('Giao dịch gần đây'),
            if (recent.isEmpty) infoCard(child: const Text('Chưa có giao dịch. Hãy thêm khoản thu hoặc chi đầu tiên.')),
            ...recent.map((e) => EntryTile(Map<String, dynamic>.from(e as Map))),
          ]);
        },
      ),
    );
  }
}

class EntryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const EntryTile(this.item, {super.key});
  @override Widget build(BuildContext context) {
    final income = item['type'] == 'INCOME';
    return Padding(padding: const EdgeInsets.only(bottom: 9), child: infoCard(child: Row(children: [
      CircleAvatar(backgroundColor: income ? const Color(0xFFE3F8F2) : const Color(0xFFFFEBEE),
        child: Icon(income ? Icons.south_west : Icons.north_east, color: income ? green : red)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${item['category']}', style: const TextStyle(fontWeight: FontWeight.w600, color: dark)),
        const SizedBox(height: 3), Text('${item['occurredOn']} · ${item['note'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 12)),
      ])),
      Text('${income ? '+' : '−'}${money(item['amount'])}', style: TextStyle(fontSize: 13, color: income ? green : red, fontWeight: FontWeight.w600)),
    ])));
  }
}

class TransactionTab extends ConsumerWidget {
  const TransactionTab({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(transactionProvider);
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => loadError(e, () => ref.invalidate(transactionProvider)),
      data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
        Text(items.length.toString()+' giao dịch đã lên cloud',
          style:const TextStyle(color:muted)),
        FutureBuilder<List<Map<String,Object?>>>(
          future:OfflineQueue.pending(ref.watch(authProvider).userEmail ?? ''),
          builder:(context,snapshot){
            final list=snapshot.data ?? [];
            if(list.isEmpty)return const SizedBox.shrink();
            return Padding(padding:const EdgeInsets.symmetric(vertical:12),
              child:infoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(list.length.toString()+' giao dịch chờ đồng bộ',
                    style:const TextStyle(color:red,fontWeight:FontWeight.bold)),
                  const Text('Chưa cộng vào số dư. Chọn biểu tượng đồng bộ ở thanh tiêu đề.',
                    style:TextStyle(color:muted,fontSize:12)),
                ])));
          }),
        const SizedBox(height:12),
        if (items.isEmpty) infoCard(child: const Text('Chưa có giao dịch nào.')),
        ...items.map((e) => Dismissible(key: ValueKey(e['id']), direction: DismissDirection.endToStart,
          background: Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(20),
            alignment: Alignment.centerRight, color: red, child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (_) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('Xóa giao dịch?'), content: const Text('Hành động này không thể hoàn tác.'), actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
            ])) ?? false,
          onDismissed: (_) async {
            try { await ref.read(apiProvider).delete('/transactions/${e['id']}'); refreshData(ref); }
            catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(error)))); refreshData(ref); }
          }, child: InkWell(onTap: () => showTransactionForm(context, ref, current: e), child: EntryTile(e)),
        )),
      ]),
    );
  }
}

class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(budgetProvider);
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => loadError(e, () => ref.invalidate(budgetProvider)),
      data: (items) => ListView(padding: const EdgeInsets.all(16), children: [
        const MonthPicker(),
        FilledButton.icon(onPressed: () => showBudgetForm(context, ref), icon: const Icon(Icons.add), label: const Text('Thiết lập ngân sách')),
        section('Ngân sách theo danh mục'),
        if (items.isEmpty) infoCard(child: const Text('Chưa có ngân sách trong tháng này.')),
        ...items.map((b) {
          final used = (b['usedPercent'] as num).toInt();
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${b['category']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Text('$used%', style: TextStyle(color: used >= 90 ? red : brand, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 6), Text('${money(b['spent'])} / ${money(b['amount'])}', style: const TextStyle(color: muted)),
            const SizedBox(height: 11), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
              value: (used / 100).clamp(0.0, 1.0), minHeight: 10,
              backgroundColor: const Color(0xFFEDF0FD), color: used >= 90 ? red : brand)),
            const SizedBox(height: 8), if (used >= 90) const Text('Cảnh báo: ngân sách sắp hoặc đã vượt hạn mức!', style: TextStyle(color: red, fontSize: 12)),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => showBudgetForm(context, ref, current: b), child: const Text('Điều chỉnh'))),
          ])));
        }),
      ]),
    );
  }
}

class StatisticsTab extends ConsumerWidget {
  const StatisticsTab({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(summaryProvider);
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => loadError(e, () => ref.invalidate(summaryProvider)),
      data: (data) {
        final categories = Map<String, dynamic>.from(data['byCategory'] as Map? ?? {});
        final entries = categories.entries.toList()..sort((a,b) => amountOf(b.value).compareTo(amountOf(a.value)));
        final total = amountOf(data['expense']);
        const palette = [brand, green, red, Color(0xFFFFB84D), Color(0xFF9B8AE8), Colors.teal, Colors.indigo];
        return ListView(padding: const EdgeInsets.all(16), children: [
          const MonthPicker(), section('Tổng chi tiêu'),
          infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(money(total), style: const TextStyle(color: brand, fontWeight: FontWeight.bold, fontSize: 28)),
            const SizedBox(height: 12), SizedBox(height: 190,
              child: total <= 0 ? const Center(child: Text('Chưa có dữ liệu để vẽ biểu đồ')) : PieChart(PieChartData(
                sectionsSpace: 3, centerSpaceRadius: 44,
                sections: [for (var i=0; i<entries.length; i++) PieChartSectionData(
                  color: palette[i % palette.length], value: amountOf(entries[i].value),
                  radius: 40, showTitle: false,
                )],
              ))),
          ])),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Xuất báo cáo tháng ra PDF'),
            onPressed: () async {
              try {
                final all = await ref.read(transactionProvider.future);
                await exportMonthlyPdf(
                  month: ref.read(monthProvider),
                  summary: data, transactions: all,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không xuất được PDF: ${apiError(e)}')));
                }
              }
            },
          ),
          section('Danh mục chi tiêu'),
          if (entries.isEmpty) infoCard(child: const Text('Chưa có khoản chi trong tháng này.')),
          for (var i=0; i<entries.length; i++) Padding(padding: const EdgeInsets.only(bottom: 9),
            child: infoCard(child: Row(children: [
              CircleAvatar(radius: 7, backgroundColor: palette[i % palette.length]), const SizedBox(width: 10),
              Expanded(child: Text(entries[i].key)), Text(money(entries[i].value), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]))),
        ]);
      },
    );
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider);
    final wallets = ref.watch(walletProvider);
    return ListView(padding: const EdgeInsets.all(16), children: [
      infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(backgroundColor: Color(0xFFEDF0FD), radius: 26,
          child: Icon(Icons.person, color: brand, size: 32)), const SizedBox(height: 10),
        Text(account.displayName ?? 'Tài khoản', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(account.userEmail ?? '', style: const TextStyle(color: muted)),
      ])),
      section('Ví của tôi'),
      wallets.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => loadError(e, () => ref.invalidate(walletProvider)),
        data: (items) => Column(children: [
          for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: infoCard(child: Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, color: brand), const SizedBox(width: 12),
            Expanded(child: Text('${w['name']}', style: const TextStyle(fontWeight: FontWeight.w600))), Text(money(w['balance'])),
          ]))),
        ])),
      OutlinedButton.icon(onPressed: () => showWalletForm(context, ref), icon: const Icon(Icons.add), label: const Text('Thêm ví mới')),
      const SizedBox(height: 28),
      OutlinedButton.icon(onPressed: () async => ref.read(authProvider.notifier).logout(),
        icon: const Icon(Icons.logout), label: const Text('Đăng xuất')),
    ]);
  }
}

Future<void> showTransactionForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? current}) async {
  final email=ref.read(authProvider).userEmail ?? '';
  List<Map<String,dynamic>> available;
  try{
    available=await ref.read(walletProvider.future);
    await OfflineQueue.rememberWallets(email,available);
  }catch(_){
    available=await OfflineQueue.wallets(email);
  }
  if (available.isEmpty) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy tạo ví trước.')));
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
    builder: (_) => _TransactionForm(wallets: available, current: current));
}

class _TransactionForm extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> wallets;
  final Map<String, dynamic>? current;
  const _TransactionForm({required this.wallets, this.current});
  @override ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}
class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount;
  late final TextEditingController note;
  late String type, category, walletId;
  late DateTime date;
  bool saving = false;
  @override void initState() {
    super.initState();
    final item = widget.current;
    type = item?['type']?.toString() ?? 'EXPENSE';
    category = item?['category']?.toString() ?? expenseCategories.first;
    walletId = item?['walletId']?.toString() ?? widget.wallets.first['id'].toString();
    date = item?['occurredOn'] == null ? DateTime.now() : DateTime.parse(item!['occurredOn'].toString());
    amount = TextEditingController(text: item == null ? '' : amountOf(item['amount']).toStringAsFixed(0));
    note = TextEditingController(text: item?['note']?.toString() ?? '');
  }
  @override void dispose() {amount.dispose();note.dispose();super.dispose();}

  Future<void> importReceipt() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Quét hóa đơn'),
        content: const Text('Ảnh được nhận dạng trên thiết bị và không gửi lên API.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Hủy')),
          TextButton.icon(onPressed: () => Navigator.pop(dialog, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined), label: const Text('Thư viện')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialog, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera')),
        ],
      ),
    );
    if (source == null || !mounted) return;
    setState(() => saving = true);
    try {
      final scan = await scanReceipt(source);
      if (scan == null || !mounted) return;
      final accept = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Kiểm tra kết quả OCR'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cửa hàng: ${scan.merchant.isEmpty ? "Chưa nhận dạng" : scan.merchant}'),
              const SizedBox(height: 8),
              Text('Số tiền gợi ý: ${scan.amount == null ? "Không tìm thấy" : money(scan.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(scan.hasTotalLabel ? 'Có dòng tổng tiền; hãy đối chiếu lại.'
                : 'Không tìm thấy nhãn tổng tiền rõ ràng; cần kiểm tra kỹ số tiền.',
                style: const TextStyle(color: muted)),
              const SizedBox(height: 14),
              const Text('Văn bản đã đọc:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SelectableText(scan.rawText.length > 1000
                ? '${scan.rawText.substring(0,1000)}…' : scan.rawText),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Bỏ qua')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Điền vào biểu mẫu')),
          ],
        ),
      );
      if (!mounted || accept != true) return;
      setState(() {
        type = 'EXPENSE';
        category = expenseCategories.first;
        if (scan.amount != null) amount.text = scan.amount.toString();
        if (scan.merchant.isNotEmpty) note.text = 'Hóa đơn: ${scan.merchant}';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã điền dữ liệu. Kiểm tra danh mục và số tiền trước khi lưu.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không đọc được hóa đơn: $error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final payload = <String, dynamic>{
        'walletId': walletId,'type': type,'category': category,
        'amount': double.parse(amount.text.trim()),'note': note.text.trim(),
        'occurredOn': DateFormat('yyyy-MM-dd').format(date),
      };
      if(widget.current!=null){
        await ref.read(apiProvider).put('/transactions/'+widget.current!['id'].toString(),payload);
      }else{
        final owner=ref.read(authProvider).userEmail ?? '';
        if(owner.isEmpty)throw StateError('Cần đăng nhập');
        // Persist first, before any network attempt, to survive lost responses.
        await OfflineQueue.enqueue(owner,payload);
        try{await OfflineQueue.sync(owner,ref.read(apiProvider));}catch(_){}
      }
      refreshData(ref);
      if(mounted){
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:
          Text('Giao dịch đã lưu. Nếu mất mạng sẽ tự gửi khi có mạng.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) {
    final options = type == 'EXPENSE' ? expenseCategories : incomeCategories;
    if (!options.contains(category)) category = options.first;
    return Padding(padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.current == null ? 'Thêm giao dịch' : 'Sửa giao dịch', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SegmentedButton<String>(segments: const [
            ButtonSegment(value: 'EXPENSE', label: Text('Chi tiêu'), icon: Icon(Icons.arrow_upward)),
            ButtonSegment(value: 'INCOME', label: Text('Thu nhập'), icon: Icon(Icons.arrow_downward)),
          ], selected: {type}, onSelectionChanged: (value) => setState(() { type = value.first;category = type == 'EXPENSE' ? expenseCategories.first : incomeCategories.first; })),
          const SizedBox(height: 13),
          if (widget.current == null && type == 'EXPENSE') ...[
            OutlinedButton.icon(onPressed: saving ? null : importReceipt,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Quét hóa đơn bằng camera / thư viện')),
            const SizedBox(height: 12),
          ],
          TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Số tiền (VND)'),
            validator: (text) => (double.tryParse(text?.trim() ?? '') ?? 0) <= 0 ? 'Nhập số tiền lớn hơn 0' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: walletId, decoration: const InputDecoration(labelText: 'Ví'),
            items: [for (final w in widget.wallets) DropdownMenuItem(value: w['id'].toString(), child: Text('${w['name']}'))],
            onChanged: (value) => setState(() => walletId = value!)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(key: ValueKey(type), initialValue: category, decoration: const InputDecoration(labelText: 'Danh mục'),
            items: [for (final c in options) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (value) => setState(() => category = value!)),
          const SizedBox(height: 12),
          TextFormField(controller: note, maxLength: 500, decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)')),
          TextButton.icon(onPressed: () async {
            final result = await showDatePicker(context: context, initialDate: date,
              firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (result != null) setState(() => date = result);
          }, icon: const Icon(Icons.calendar_today_outlined), label: Text('Ngày: ${DateFormat('dd/MM/yyyy').format(date)}')),
          const SizedBox(height: 12),
          FilledButton(onPressed: saving ? null : save,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(saving ? 'Đang lưu...' : 'Lưu giao dịch'))),
        ],
      ))),
    );
  }
}

Future<void> showWalletForm(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(context: context, isScrollControlled: true,
    builder: (_) => const _WalletForm());
}
class _WalletForm extends ConsumerStatefulWidget {
  const _WalletForm();
  @override ConsumerState<_WalletForm> createState() => _WalletFormState();
}
class _WalletFormState extends ConsumerState<_WalletForm> {
  final name = TextEditingController(), initial = TextEditingController(text: '0');
  bool saving = false;
  @override void dispose() {name.dispose();initial.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(18, 22, 18, MediaQuery.of(context).viewInsets.bottom + 30),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Tạo ví mới', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên ví')),
      const SizedBox(height: 12),
      TextField(controller: initial, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Số dư ban đầu (VND)')),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : () async {
        if (name.text.trim().isEmpty || (double.tryParse(initial.text) ?? -1) < 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiểm tra tên ví và số dư')));return;
        }
        setState(() => saving = true);
        try {
          await ref.read(apiProvider).post('/wallets', {'name': name.text.trim(), 'openingBalance': double.parse(initial.text)});
          refreshData(ref);if (context.mounted) Navigator.pop(context);
        } catch (e) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));}
        finally {if (mounted) setState(() => saving = false);}
      }, child: Text(saving ? 'Đang lưu...' : 'Tạo ví')),
    ]),
  );
}

Future<void> showBudgetForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? current}) async {
  await showModalBottomSheet<void>(context: context, isScrollControlled: true,
    builder: (_) => _BudgetForm(current: current));
}
class _BudgetForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? current;
  const _BudgetForm({this.current});
  @override ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}
class _BudgetFormState extends ConsumerState<_BudgetForm> {
  late String category;
  late final TextEditingController amount;
  bool saving = false;
  @override void initState() {
    super.initState();category = widget.current?['category']?.toString() ?? expenseCategories.first;
    amount = TextEditingController(text: widget.current == null ? '' : amountOf(widget.current!['amount']).toStringAsFixed(0));
  }
  @override void dispose() {amount.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(18, 22, 18, MediaQuery.of(context).viewInsets.bottom + 30),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Thiết lập ngân sách', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Danh mục'),
        items: [for (final c in expenseCategories) DropdownMenuItem(value: c, child: Text(c))],
        onChanged: (value) => setState(() => category = value!)),
      const SizedBox(height: 12),
      TextField(controller: amount, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Hạn mức (VND)')),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : () async {
        final value = double.tryParse(amount.text);
        if (value == null || value <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập hạn mức lớn hơn 0')));return;
        }
        setState(() => saving = true);
        try {
          await ref.read(apiProvider).post('/budgets', {
            'category': category, 'month': monthKey(ref.read(monthProvider)), 'amount': value,
          });
          refreshData(ref);if (context.mounted) Navigator.pop(context);
        } catch (e) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));}
        finally {if (mounted) setState(() => saving = false);}
      }, child: Text(saving ? 'Đang lưu...' : 'Lưu ngân sách')),
    ]),
  );
}
