import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'screens.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const ProviderScope(child: MoneyMateApp())); }

class MoneyMateApp extends ConsumerWidget {
  const MoneyMateApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'MoneyMate', debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2147D7),
          primary: const Color(0xFF2147D7),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F6FA),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE8EEFF),
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? const Color(0xFF2147D7) : const Color(0xFF7B8498),
            )),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      home: apiBaseUrl.isEmpty || !apiBaseUrl.startsWith('https://')
          ? const CloudSetupScreen()
          : auth.loading ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.loggedIn ? const HomeShell() : const AuthScreen(),
    );
  }
}

class CloudSetupScreen extends StatelessWidget {
  const CloudSetupScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Padding(padding: EdgeInsets.all(28), child: Column(
      mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off_outlined, size: 55), SizedBox(height: 20),
      Text('MoneyMate cần API cloud', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 12), Text('Hãy build ứng dụng với --dart-define=API_BASE_URL=https://TEN-API.onrender.com. Ứng dụng không sử dụng localhost.', textAlign: TextAlign.center)],
    ))),
  );
}
