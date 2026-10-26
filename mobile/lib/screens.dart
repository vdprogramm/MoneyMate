import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_scanner.dart';
import 'receipt_parser.dart';
import 'report_export.dart';
import 'offline_queue.dart';

const brand = Color(0xFF2147D7);
const dark = Color(0xFF151B2B);
const green = Color(0xFF159A75);
const red = Color(0xFFF04F55);
const muted = Color(0xFF7B8498);
const canvas = Color(0xFFF5F6FA);
const expenseCategories = ['Ăn uống', 'Mua sắm', 'Di chuyển', 'Nhà ở', 'Hóa đơn', 'Giải trí', 'Sức khỏe', 'Giáo dục', 'Khác'];
const incomeCategories = ['Lương', 'Thưởng', 'Đầu tư', 'Quà tặng', 'Khác'];

String money(dynamic value) {
  final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return '${NumberFormat('#,##0', 'vi').format(amount)} ₫';
}
double amountOf(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Widget section(String title) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 12),
  child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
);
Widget infoCard({required Widget child, EdgeInsets? padding}) => Container(
  width: double.infinity,
  padding: padding ?? const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFF0F2F7)),
    boxShadow: const [
      BoxShadow(color: Color(0x07182748), blurRadius: 18, offset: Offset(0, 6)),
    ],
  ),
  child: child,
);

IconData categoryIcon(String category) {
  switch (category) {
    case 'Ăn uống': return Icons.restaurant_rounded;
    case 'Mua sắm': return Icons.shopping_bag_rounded;
    case 'Di chuyển': return Icons.directions_car_rounded;
    case 'Nhà ở': return Icons.home_rounded;
    case 'Hóa đơn': return Icons.receipt_long_rounded;
    case 'Giải trí': return Icons.sports_esports_rounded;
    case 'Sức khỏe': return Icons.favorite_rounded;
    case 'Giáo dục': return Icons.school_rounded;
    case 'Lương': return Icons.payments_rounded;
    case 'Thưởng': return Icons.card_giftcard_rounded;
    case 'Đầu tư': return Icons.trending_up_rounded;
    case 'Quà tặng': return Icons.redeem_rounded;
    default: return Icons.category_rounded;
  }
}

Color categoryColor(String category) {
  switch (category) {
    case 'Ăn uống': return const Color(0xFFFFEEE9);
    case 'Mua sắm': return const Color(0xFFFFF2D9);
    case 'Di chuyển': return const Color(0xFFE7EEFF);
    case 'Nhà ở': return const Color(0xFFE8F6EE);
    case 'Hóa đơn': return const Color(0xFFF0EAFE);
    case 'Giải trí': return const Color(0xFFFFE8EF);
    case 'Sức khỏe': return const Color(0xFFFFE9EB);
    case 'Giáo dục': return const Color(0xFFE4F4FF);
    default: return const Color(0xFFEAF0FF);
  }
}
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
        if(pendingCount>0) Center(child:Text('$pendingCount chờ gửi',
          style:const TextStyle(fontSize:12,color:red))),
        IconButton(onPressed:syncing?null:syncPending,tooltip:'Đồng bộ offline',
          icon:Icon(syncing?Icons.hourglass_top:Icons.sync)),
        IconButton(onPressed:()=>refreshData(ref),icon:const Icon(Icons.refresh))]),
      body: IndexedStack(index: index, children: const [DashboardTab(), TransactionTab(), BudgetTab(), StatisticsTab(), ProfileTab()]),
      floatingActionButton: index == 0 || index == 1
          ? FloatingActionButton(
              tooltip: 'Thêm giao dịch',
              backgroundColor: brand,
              foregroundColor: Colors.white,
              elevation: 5,
              onPressed: () => showTransactionForm(context, ref),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
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

class _WeeklyCashflowChart extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  const _WeeklyCashflowChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - index)),
    );
    final income = List<double>.filled(7, 0);
    final expense = List<double>.filled(7, 0);

    for (final item in transactions) {
      final rawDate = item['occurredOn'];
      if (rawDate == null) continue;
      DateTime date;
      try {
        date = DateTime.parse(rawDate.toString());
      } catch (_) {
        continue;
      }
      final index = days.indexWhere((day) =>
          day.year == date.year && day.month == date.month && day.day == date.day);
      if (index < 0) continue;
      if (item['type'] == 'INCOME') {
        income[index] += amountOf(item['amount']);
      } else {
        expense[index] += amountOf(item['amount']);
      }
    }

    final hasActivity = income.any((value) => value > 0) ||
        expense.any((value) => value > 0);
    if (!hasActivity) {
      return const Center(
        child: Text(
          'Chưa có giao dịch trong 7 ngày gần đây',
          style: TextStyle(color: muted, fontSize: 13),
        ),
      );
    }
    final peak = [...income, ...expense].fold<double>(
      0,
      (largest, value) => value > largest ? value : largest,
    );
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: peak <= 0 ? 100 : peak * 1.25,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 10,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 25,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final day = days[index];
                final label = day.weekday == DateTime.sunday
                    ? 'CN'
                    : 'T${day.weekday + 1}';
                return Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          7,
          (index) => BarChartGroupData(
            x: index,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: income[index],
                color: green,
                width: 8,
                borderRadius: BorderRadius.circular(5),
              ),
              BarChartRodData(
                toY: expense[index],
                color: red,
                width: 8,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(summaryProvider);
    final transactions = ref.watch(transactionProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final account = ref.watch(authProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshData(ref);
        await ref.read(summaryProvider.future);
      },
      child: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => loadError(e, () => ref.invalidate(summaryProvider)),
        data: (data) {
          final recent = (data['recentTransactions'] as List? ?? []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QUẢN LÝ TÀI CHÍNH CỦA BẠN',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Xin chào, $account.displayName ?? "bạn"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: dark,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: brand,
                      size: 25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const MonthPicker(),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2147D7), Color(0xFF355DF0)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x302147D7),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'SỐ DƯ HIỆN TẠI',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0x26FFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(data['totalBalance']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Tổng số dư trong tất cả ví',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: Colors.white24),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: const BoxDecoration(
                                  color: Color(0x26FFFFFF),
                                  borderRadius: BorderRadius.all(Radius.circular(13)),
                                ),
                                child: const Icon(
                                  Icons.south_west_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Thu nhập',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        money(data['income']),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: const BoxDecoration(
                                  color: Color(0x26FFFFFF),
                                  borderRadius: BorderRadius.all(Radius.circular(13)),
                                ),
                                child: const Icon(
                                  Icons.north_east_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chi tiêu',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        money(data['expense']),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              section('Biến động thu chi'),
              infoCard(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: Column(
                  children: [
                    SizedBox(
                      height: 175,
                      child: _WeeklyCashflowChart(transactions: transactions),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: green,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Thu nhập',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Chi tiêu',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              section('Giao dịch gần đây'),
              if (recent.isEmpty)
                infoCard(
                  child: const Column(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: muted, size: 34),
                      SizedBox(height: 8),
                      Text(
                        'Chưa có giao dịch nào',
                        style: TextStyle(color: dark, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Thêm khoản thu hoặc chi đầu tiên của bạn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ...recent.map((item) {
                final transaction = Map<String, dynamic>.from(item as Map);
                return InkWell(onTap: () => showTransactionDetail(context, ref, transaction), child: EntryTile(transaction));
              }),
            ],
          );
        },
      ),
    );
  }
}


class EntryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const EntryTile(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final income = item['type'] == 'INCOME';
    final category = item['category']?.toString() ?? 'Khác';
    final noteText = (item['note'] ?? '').toString().trim();
    final dateText = (item['occurredOn'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: infoCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: categoryColor(category),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                categoryIcon(category),
                color: income ? green : brand,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: dark,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noteText.isEmpty ? dateText : '$dateText · $noteText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${income ? '+' : '−'}${money(item['amount'])}',
                  style: TextStyle(
                    fontSize: 13,
                    color: income ? green : red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  income ? 'Thu vào' : 'Chi ra',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        Text('${items.length} giao dịch đã lên cloud',
          style:const TextStyle(color:muted)),
        FutureBuilder<List<Map<String,Object?>>>(
          future:OfflineQueue.pending(ref.watch(authProvider).userEmail ?? ''),
          builder:(context,snapshot){
            final list=snapshot.data ?? [];
            if(list.isEmpty)return const SizedBox.shrink();
            return Padding(padding:const EdgeInsets.symmetric(vertical:12),
              child:infoCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('${list.length} giao dịch chờ đồng bộ',
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
          }, child: InkWell(onTap: () => showTransactionDetail(context, ref, e), child: EntryTile(e)),
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
      section('Trung tâm tiện ích'),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55,
        children: [
          _ProfileShortcut(icon: Icons.account_balance_wallet_rounded, title: 'Quản lý ví', subtitle: 'Số dư từng ví',
            tint: const Color(0xFFE8EEFF), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen()))),
          _ProfileShortcut(icon: Icons.document_scanner_rounded, title: 'Quét hóa đơn', subtitle: 'Nhận dạng OCR',
            tint: const Color(0xFFFFE8E9), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptScanScreen()))),
          _ProfileShortcut(icon: Icons.picture_as_pdf_rounded, title: 'Báo cáo PDF', subtitle: 'Xuất theo tháng',
            tint: const Color(0xFFE1F7EE), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
          _ProfileShortcut(icon: Icons.sync_rounded, title: 'Đồng bộ offline', subtitle: 'Giao dịch chờ gửi',
            tint: const Color(0xFFFFF1D7), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineSyncScreen()))),
          _ProfileShortcut(icon: Icons.settings_rounded, title: 'Cài đặt', subtitle: 'Quyền riêng tư',
            tint: const Color(0xFFF0EAFE), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      section('Ví gần đây'),
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


class _ProfileShortcut extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Color tint; final VoidCallback onTap;
  const _ProfileShortcut({required this.icon, required this.title, required this.subtitle, required this.tint, required this.onTap});
  @override Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(20),
    child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: brand, size: 22)),
        const SizedBox(height: 9),
        Text(title, style: const TextStyle(color: dark, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 10)),
      ]),
    )),
  );
}

Future<void> showTransactionDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (detailContext) => _TransactionDetailScreen(
    item: item,
    onEdit: () async {
      Navigator.of(detailContext).pop();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (context.mounted) await showTransactionForm(context, ref, current: item);
    },
  )));
}

class _TransactionDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> item; final Future<void> Function() onEdit;
  const _TransactionDetailScreen({required this.item, required this.onEdit});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final income = item['type'] == 'INCOME';
    final category = item['category']?.toString() ?? 'Khác';
    final tint = income ? green : red;
    return Scaffold(backgroundColor: canvas, appBar: AppBar(title: const Text('Chi tiết giao dịch'), backgroundColor: canvas),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
          gradient: LinearGradient(colors: income ? const [Color(0xFF078B68), Color(0xFF26B88B)] : const [Color(0xFFE94D59), Color(0xFFFF777B)]),
          borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))]),
          child: Column(children: [
            Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: Icon(categoryIcon(category), color: Colors.white, size: 30)),
            const SizedBox(height: 14),
            Text(income ? 'KHOẢN THU' : 'KHOẢN CHI', style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text((income ? '+' : '−') + money(item['amount']), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(category, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ])),
        const SizedBox(height: 18),
        infoCard(child: Column(children: [
          _DetailRow(icon: Icons.calendar_month_rounded, label: 'Ngày giao dịch', value: item['occurredOn']?.toString() ?? '—'),
          const Divider(height: 24),
          _DetailRow(icon: Icons.category_rounded, label: 'Danh mục', value: category),
          const Divider(height: 24),
          _DetailRow(icon: Icons.swap_horiz_rounded, label: 'Loại giao dịch', value: income ? 'Thu nhập' : 'Chi tiêu'),
          const Divider(height: 24),
          _DetailRow(icon: Icons.notes_rounded, label: 'Ghi chú', value: (item['note']?.toString().trim().isNotEmpty ?? false) ? item['note'].toString() : 'Không có ghi chú'),
        ])),
        const SizedBox(height: 20),
        SizedBox(height: 54, child: FilledButton.icon(onPressed: () => onEdit(), icon: const Icon(Icons.edit_rounded),
          label: const Text('Chỉnh sửa giao dịch', style: TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
              title: const Text('Xóa giao dịch?'), content: const Text('Hành động này không thể hoàn tác.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Giữ lại')),
                FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Xóa giao dịch')),
              ]));
            if (confirmed != true) return;
            try {
              await ref.read(apiProvider).delete('/transactions/' + item['id'].toString());
              refreshData(ref);
              if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa giao dịch'))); Navigator.of(context).pop(); }
            } catch (error) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(error))));
            }
          },
          icon: const Icon(Icons.delete_outline_rounded), label: const Text('Xóa giao dịch'),
          style: OutlinedButton.styleFrom(foregroundColor: red, side: const BorderSide(color: Color(0xFFFFCDD0)),
            padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: brand, size: 21)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: dark, fontSize: 13, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletProvider);
    return Scaffold(backgroundColor: canvas, appBar: AppBar(title: const Text('Ví của tôi'), backgroundColor: canvas),
      body: wallets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => loadError(error, () => ref.invalidate(walletProvider)),
        data: (items) {
          final total = items.fold<double>(0, (sum, wallet) => sum + amountOf(wallet['balance']));
          return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
            Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2147D7), Color(0xFF5275F7)]), borderRadius: BorderRadius.circular(26)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TỔNG SỐ DƯ', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10), Text(money(total), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8), Text(items.length.toString() + ' ví đang quản lý', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            const SizedBox(height: 20),
            const Text('Danh sách ví', style: TextStyle(color: dark, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (items.isEmpty) infoCard(child: const Text('Bạn chưa có ví nào. Tạo ví đầu tiên để bắt đầu quản lý số dư.')),
            for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: infoCard(
              padding: const EdgeInsets.all(17), child: Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: i.isEven ? const Color(0xFFE8EEFF) : const Color(0xFFE1F7EE), borderRadius: BorderRadius.circular(17)),
                  child: Icon(i.isEven ? Icons.account_balance_wallet_rounded : Icons.savings_rounded, color: i.isEven ? brand : green, size: 26)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(items[i]['name']?.toString() ?? 'Ví', style: const TextStyle(color: dark, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5), const Text('Số dư hiện tại', style: TextStyle(color: muted, fontSize: 11)),
                ])),
                const SizedBox(width: 8), Flexible(child: Text(money(items[i]['balance']), textAlign: TextAlign.end, style: const TextStyle(color: dark, fontSize: 14, fontWeight: FontWeight.w900))),
              ]))),
            const SizedBox(height: 8),
            SizedBox(height: 54, child: FilledButton.icon(onPressed: () => showWalletForm(context, ref), icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo ví mới', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
          ]);
        },
      ),
    );
  }
}

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});
  @override ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}
class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  ReceiptData? result; bool scanning = false;
  Future<void> scan(ImageSource source) async {
    setState(() => scanning = true);
    try {
      final found = await scanReceipt(source);
      if (mounted && found != null) setState(() => result = found);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không đọc được hóa đơn: ' + error.toString())));
    } finally { if (mounted) setState(() => scanning = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas, appBar: AppBar(title: const Text('Quét hóa đơn OCR'), backgroundColor: canvas),
    body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2147D7), Color(0xFF5275F7)]), borderRadius: BorderRadius.circular(26)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.document_scanner_rounded, color: Colors.white, size: 34), SizedBox(height: 16),
          Text('Quét nhanh, ghi chép dễ dàng', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 7), Text('Chụp hóa đơn hoặc chọn ảnh có sẵn. Hãy kiểm tra số tiền trước khi lưu giao dịch.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
        ])),
      const SizedBox(height: 16),
      infoCard(child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.verified_user_outlined, color: green), SizedBox(width: 10),
        Expanded(child: Text('Ảnh được xử lý trực tiếp trên điện thoại, không tải ảnh hóa đơn lên máy chủ.', style: TextStyle(color: dark, fontSize: 12, height: 1.5))),
      ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: SizedBox(height: 54, child: FilledButton.icon(onPressed: scanning ? null : () => scan(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_rounded), label: const Text('Chụp hóa đơn'),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 54, child: OutlinedButton.icon(onPressed: scanning ? null : () => scan(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined), label: const Text('Chọn ảnh'),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))),
      ]),
      if (scanning) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
      if (result != null) ...[
        const SizedBox(height: 20), section('Kết quả nhận dạng'),
        infoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SỐ TIỀN GỢI Ý', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 8), Text(result!.amount == null ? 'Chưa nhận dạng được' : money(result!.amount),
            style: const TextStyle(color: brand, fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.storefront_rounded, label: 'Cửa hàng', value: result!.merchant.isEmpty ? 'Chưa nhận dạng' : result!.merchant),
          const SizedBox(height: 14),
          Text(result!.hasTotalLabel ? 'Đã phát hiện nhãn tổng tiền; vẫn cần đối chiếu.' : 'Chưa phát hiện nhãn tổng tiền rõ ràng. Hãy kiểm tra số tiền.',
            style: const TextStyle(color: muted, fontSize: 12, height: 1.5)),
          const SizedBox(height: 12), const Text('Văn bản OCR', style: TextStyle(color: dark, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6), SelectableText(result!.rawText.isEmpty ? 'Không nhận dạng được văn bản.' : result!.rawText,
            style: const TextStyle(color: muted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
            onPressed: result!.amount == null ? null : () => showTransactionForm(context, ref,
              initialAmount: result!.amount.toString(),
              initialNote: result!.merchant.isEmpty ? 'Hóa đơn OCR' : 'Hóa đơn: ' + result!.merchant),
            icon: const Icon(Icons.add_rounded), label: const Text('Tạo giao dịch từ hóa đơn', style: TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(backgroundColor: red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
        ])),
      ],
    ]),
  );
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(summaryProvider);
    return Scaffold(backgroundColor: canvas, appBar: AppBar(title: const Text('Báo cáo tài chính'), backgroundColor: canvas),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => loadError(error, () => ref.invalidate(summaryProvider)),
        data: (data) {
          final income = amountOf(data['income']); final expense = amountOf(data['expense']);
          final categories = Map<String, dynamic>.from(data['byCategory'] as Map? ?? {});
          final entries = categories.entries.toList()..sort((a, b) => amountOf(b.value).compareTo(amountOf(a.value)));
          const palette = [brand, green, red, Color(0xFFFFB84D), Color(0xFF9B8AE8), Colors.teal, Colors.indigo];
          return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
            const MonthPicker(),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2147D7), Color(0xFF5275F7)]), borderRadius: BorderRadius.circular(25)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SỨC KHỎE TÀI CHÍNH', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8), Text(money(data['totalBalance']), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                const Text('Tổng số dư tất cả ví', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 18), Row(children: [
                  Expanded(child: _ReportMetric(label: 'Thu nhập', amount: income, tint: const Color(0xFFB9FFE4), icon: Icons.south_west_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _ReportMetric(label: 'Chi tiêu', amount: expense, tint: const Color(0xFFFFD2D4), icon: Icons.north_east_rounded)),
                ]),
              ])),
            const SizedBox(height: 18), section('Cơ cấu chi tiêu'),
            infoCard(child: Column(children: [
              SizedBox(height: 205, child: expense <= 0 ? const Center(child: Text('Chưa có dữ liệu chi tiêu', style: TextStyle(color: muted)))
                : PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 48,
                    sections: [for (var i = 0; i < entries.length; i++) PieChartSectionData(color: palette[i % palette.length], value: amountOf(entries[i].value), radius: 42, showTitle: false)]))),
              if (entries.isNotEmpty) ...[
                const Divider(height: 22),
                for (var i = 0; i < entries.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10), Expanded(child: Text(entries[i].key, style: const TextStyle(color: dark, fontWeight: FontWeight.w600))),
                  Text(money(entries[i].value), style: const TextStyle(color: dark, fontWeight: FontWeight.w800)),
                ])),
              ],
            ])),
            const SizedBox(height: 18),
            SizedBox(height: 54, child: FilledButton.icon(onPressed: () async {
              try {
                final all = await ref.read(transactionProvider.future);
                await exportMonthlyPdf(month: ref.read(monthProvider), summary: data, transactions: all);
              } catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xuất được PDF: ' + apiError(error))));
              }
            }, icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Xuất báo cáo tháng ra PDF', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
          ]);
        },
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label; final double amount; final Color tint; final IconData icon;
  const _ReportMetric({required this.label, required this.amount, required this.tint, required this.icon});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(17)),
    child: Row(children: [
      Icon(icon, color: tint, size: 20), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 5),
        Text(money(amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      ])),
    ]),
  );
}

class OfflineSyncScreen extends ConsumerStatefulWidget {
  const OfflineSyncScreen({super.key});
  @override ConsumerState<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}
class _OfflineSyncScreenState extends ConsumerState<OfflineSyncScreen> {
  bool syncing = false;
  Future<void> syncNow() async {
    final email = ref.read(authProvider).userEmail ?? '';
    if (email.isEmpty) return;
    setState(() => syncing = true);
    try {
      final count = await OfflineQueue.sync(email, ref.read(apiProvider));
      refreshData(ref);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đồng bộ thành công ' + count.toString() + ' giao dịch')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(error))));
    } finally { if (mounted) setState(() => syncing = false); }
  }
  @override Widget build(BuildContext context) {
    final email = ref.watch(authProvider).userEmail ?? '';
    return Scaffold(backgroundColor: canvas, appBar: AppBar(title: const Text('Đồng bộ offline'), backgroundColor: canvas),
      body: FutureBuilder<List<Map<String, Object?>>>(future: OfflineQueue.pending(email), builder: (context, snapshot) {
        final drafts = snapshot.data ?? [];
        return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFFFFF1D7), borderRadius: BorderRadius.circular(24)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.sync_rounded, color: Color(0xFF9B6500), size: 30), SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Giao dịch an toàn khi mất mạng', style: TextStyle(color: dark, fontSize: 16, fontWeight: FontWeight.w900)),
                SizedBox(height: 6), Text('Giao dịch offline được lưu vào hàng đợi trên máy. Khi có mạng, MoneyMate gửi lên máy chủ bằng mã riêng để tránh tạo bản trùng.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
              ])),
            ])),
          const SizedBox(height: 18),
          Text(drafts.length.toString() + ' giao dịch đang chờ', style: const TextStyle(color: dark, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (snapshot.connectionState != ConnectionState.waiting && drafts.isEmpty) infoCard(child: const Column(children: [
            Icon(Icons.cloud_done_rounded, color: green, size: 38), SizedBox(height: 8),
            Text('Bạn đã cập nhật', style: TextStyle(color: dark, fontWeight: FontWeight.w800)), SizedBox(height: 4),
            Text('Không có giao dịch nào đang chờ đồng bộ.', style: TextStyle(color: muted, fontSize: 12)),
          ])),
          for (final draft in drafts) Padding(padding: const EdgeInsets.only(bottom: 10), child: infoCard(child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFE8E9), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.cloud_upload_outlined, color: red)),
            const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Giao dịch cục bộ', style: TextStyle(color: dark, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
              Text(draft['error']?.toString() ?? 'Sẵn sàng gửi khi có mạng', style: const TextStyle(color: muted, fontSize: 11)),
            ])), const Icon(Icons.schedule_rounded, color: muted),
          ]))),
          const SizedBox(height: 12),
          SizedBox(height: 54, child: FilledButton.icon(onPressed: syncing || email.isEmpty ? null : syncNow,
            icon: Icon(syncing ? Icons.hourglass_top_rounded : Icons.sync_rounded),
            label: Text(syncing ? 'Đang đồng bộ...' : 'Đồng bộ ngay', style: const TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
        ]);
      }),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider);
    return Scaffold(backgroundColor: canvas, appBar: AppBar(title: const Text('Cài đặt & bảo mật'), backgroundColor: canvas),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
        infoCard(child: Row(children: [
          const CircleAvatar(radius: 28, backgroundColor: Color(0xFFE8EEFF), child: Icon(Icons.person_rounded, color: brand, size: 30)),
          const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(account.displayName ?? 'Tài khoản', style: const TextStyle(color: dark, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4), Text(account.userEmail ?? '', style: const TextStyle(color: muted, fontSize: 12)),
          ])),
        ])),
        const SizedBox(height: 18), section('Quyền riêng tư'),
        infoCard(child: const Column(children: [
          _SettingsRow(icon: Icons.lock_outline_rounded, title: 'Đăng nhập bảo mật', subtitle: 'Phiên đăng nhập được lưu bằng bộ nhớ bảo mật của thiết bị.'),
          Divider(height: 24),
          _SettingsRow(icon: Icons.document_scanner_outlined, title: 'OCR trên thiết bị', subtitle: 'Ảnh hóa đơn được xử lý cục bộ; dữ liệu chỉ được lưu khi bạn xác nhận giao dịch.'),
          Divider(height: 24),
          _SettingsRow(icon: Icons.cloud_sync_outlined, title: 'Đồng bộ dữ liệu', subtitle: 'Giao dịch offline được giữ trong hàng đợi trên thiết bị cho đến khi đồng bộ thành công.'),
        ])),
        const SizedBox(height: 18), section('Quản lý ứng dụng'),
        _SettingsLink(icon: Icons.sync_rounded, title: 'Hàng đợi đồng bộ offline', subtitle: 'Xem giao dịch chưa gửi lên cloud',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineSyncScreen()))),
        _SettingsLink(icon: Icons.picture_as_pdf_rounded, title: 'Báo cáo tài chính', subtitle: 'Xem biểu đồ và xuất báo cáo PDF',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
        _SettingsLink(icon: Icons.account_balance_wallet_rounded, title: 'Quản lý ví', subtitle: 'Xem số dư của từng ví',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen()))),
        const SizedBox(height: 20),
        const Center(child: Column(children: [
          Text('MoneyMate', style: TextStyle(color: brand, fontWeight: FontWeight.w900, fontSize: 15)), SizedBox(height: 4),
          Text('Phiên bản 0.3.0 · Personal finance', style: TextStyle(color: muted, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _SettingsRow({required this.icon, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE8EEFF), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: brand)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w800)), const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 11, height: 1.5)),
    ])),
  ]);
}

class _SettingsLink extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _SettingsLink({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: infoCard(
    padding: const EdgeInsets.all(15), child: InkWell(onTap: onTap, child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE8EEFF), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: brand)),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: dark, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
      ])), const Icon(Icons.chevron_right_rounded, color: muted),
    ])),
  ));
}

Future<void> showTransactionForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? current, String? initialAmount, String? initialNote}) async {
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
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      height: MediaQuery.of(sheetContext).size.height * 0.96,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _TransactionForm(wallets: available, current: current, initialAmount: initialAmount, initialNote: initialNote),
    ),
  );
}

class _TransactionForm extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> wallets;
  final Map<String, dynamic>? current;
  final String? initialAmount;
  final String? initialNote;
  const _TransactionForm({required this.wallets, this.current, this.initialAmount, this.initialNote});
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
    amount = TextEditingController(text: item == null ? (widget.initialAmount ?? '') : amountOf(item['amount']).toStringAsFixed(0));
    note = TextEditingController(text: item?['note']?.toString() ?? widget.initialNote ?? '');
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
        await ref.read(apiProvider).put('/transactions/${widget.current!['id']}',payload);
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
  @override
  Widget build(BuildContext context) {
    final options = type == 'EXPENSE' ? expenseCategories : incomeCategories;
    if (!options.contains(category)) category = options.first;
    final activeColor = type == 'EXPENSE' ? red : green;
    return SafeArea(
      top: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              icon: const Icon(Icons.arrow_back_rounded)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.current == null
                  ? (type == 'EXPENSE' ? 'Thêm khoản chi' : 'Thêm khoản thu')
                  : 'Chỉnh sửa giao dịch',
                style: const TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w800)),
              const Text('Ghi lại để quản lý tài chính tốt hơn',
                style: TextStyle(color: muted, fontSize: 11)),
            ])),
            if (widget.current == null && type == 'EXPENSE')
              IconButton(tooltip: 'Quét hóa đơn', onPressed: saving ? null : importReceipt,
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8EEFF), foregroundColor: brand),
                icon: const Icon(Icons.document_scanner_outlined)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFF0F2F7)),
                boxShadow: const [BoxShadow(color: Color(0x07182748), blurRadius: 18, offset: Offset(0, 6))]),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF2F3F7), borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Expanded(child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() { type = 'EXPENSE'; category = expenseCategories.first; }),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: type == 'EXPENSE' ? red : Colors.transparent,
                          borderRadius: BorderRadius.circular(14)),
                        child: Text('Chi tiêu', textAlign: TextAlign.center,
                          style: TextStyle(color: type == 'EXPENSE' ? Colors.white : muted, fontWeight: FontWeight.w800))))),
                    Expanded(child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() { type = 'INCOME'; category = incomeCategories.first; }),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: type == 'INCOME' ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(14)),
                        child: Text('Thu nhập', textAlign: TextAlign.center,
                          style: TextStyle(color: type == 'INCOME' ? Colors.white : muted, fontWeight: FontWeight.w800))))),
                  ]),
                ),
                const SizedBox(height: 24),
                const Text('SỐ TIỀN GIAO DỊCH',
                  style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                const SizedBox(height: 5),
                Row(children: [
                  Text('₫', style: TextStyle(color: activeColor, fontSize: 30, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center,
                    style: const TextStyle(color: dark, fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1),
                    decoration: const InputDecoration(hintText: '0', filled: false, isDense: true,
                      border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero),
                    validator: (value) => (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                      ? 'Nhập số tiền lớn hơn 0' : null)),
                ]),
                const Text('Việt Nam đồng (VND)', style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            section('Danh mục'),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 12, mainAxisExtent: 94),
              itemBuilder: (context, index) {
                final item = options[index];
                final selected = item == category;
                return InkWell(borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => category = item),
                  child: Column(children: [
                    AnimatedContainer(duration: const Duration(milliseconds: 160), width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: selected ? (type == 'EXPENSE' ? const Color(0xFFFFE8E9) : const Color(0xFFE2F7EF)) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: selected ? activeColor : const Color(0xFFE9ECF3), width: selected ? 1.8 : 1)),
                      child: Icon(categoryIcon(item), color: selected ? activeColor : muted, size: 25)),
                    const SizedBox(height: 7),
                    Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                      style: TextStyle(color: selected ? dark : muted, fontSize: 10,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
                  ]),
                );
              },
            ),
            section('Chi tiết giao dịch'),
            infoCard(padding: const EdgeInsets.all(14), child: Column(children: [
              InkWell(borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final result = await showDatePicker(context: context, initialDate: date,
                    firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (result != null) setState(() => date = result);
                },
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.calendar_month_rounded, color: brand)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Ngày giao dịch', style: TextStyle(color: muted, fontSize: 11)),
                      const SizedBox(height: 3),
                      Text(DateFormat('dd/MM/yyyy').format(date),
                        style: const TextStyle(color: dark, fontSize: 13, fontWeight: FontWeight.w700)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: muted),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(key: ValueKey('wallet-$walletId'), initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Ví', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                items: [for (final wallet in widget.wallets)
                  DropdownMenuItem(value: wallet['id'].toString(), child: Text('${wallet['name']}'))],
                onChanged: (value) { if (value != null) setState(() => walletId = value); }),
              const SizedBox(height: 12),
              TextFormField(controller: note, maxLength: 500,
                decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)',
                  prefixIcon: Icon(Icons.notes_rounded), counterText: '')),
            ])),
            if (widget.current == null && type == 'EXPENSE') ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: saving ? null : importReceipt,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Quét hóa đơn bằng camera / thư viện'),
                style: OutlinedButton.styleFrom(foregroundColor: brand,
                  side: const BorderSide(color: Color(0xFFD9E2FF)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
            ],
          ])),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(width: double.infinity, height: 60,
            child: FilledButton.icon(onPressed: saving ? null : save,
              icon: Icon(saving ? Icons.hourglass_top_rounded : Icons.check_rounded),
              label: Text(saving ? 'Đang lưu...' : 'Lưu giao dịch',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: activeColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)), elevation: 0)))),
      ]),
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
