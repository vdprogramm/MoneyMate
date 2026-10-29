import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'offline_queue.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const storage = FlutterSecureStorage();

class Api {
  late final Dio dio;
  Api() {
    dio = Dio(BaseOptions(
      baseUrl: '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/api/v1',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 35),
      headers: {'Accept': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await storage.read(key: 'jwt');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  /// Wait for a sleeping Render service to wake before submitting credentials.
  Future<void> waitForServer() async {
    final base = apiBaseUrl.replaceFirst(RegExp(r'/
      Map<String, dynamic>.from((await dio.post(path, data: body)).data as Map);
  Future<List<Map<String, dynamic>>> getList(String path) async =>
      ((await dio.get(path)).data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<Map<String, dynamic>> getMap(String path) async =>
      Map<String, dynamic>.from((await dio.get(path)).data as Map);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from((await dio.put(path, data: body)).data as Map);
  Future<void> delete(String path) async { await dio.delete(path); }
}

final apiProvider = Provider<Api>((ref) => Api());

String apiError(Object error) {
  if (error is TimeoutException) {
    return error.message ?? 'Máy chủ phản hồi quá chậm. Vui lòng thử lại.';
  }
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    final code = error.response?.statusCode;
    if (code == 401) return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.';
    if (code == 403) return 'Bạn không có quyền truy cập dữ liệu này.';
    if (code == 404) return 'Không tìm thấy dữ liệu được yêu cầu.';
    if (code == 409) return 'Dữ liệu đã tồn tại hoặc bị xung đột.';
    if (code != null && code >= 500) return 'Máy chủ đang bận. Thử lại sau.';
    if (code != null && code >= 400) return 'Yêu cầu không hợp lệ (HTTP $code).';
    return 'Không thể kết nối đến máy chủ. Kiểm tra Internet và API.';
  }
  return error.toString();
}

class AuthState {
  final bool loading;
  final String? userEmail;
  final String? displayName;
  final bool loggedIn;
  const AuthState({this.loading = false, this.userEmail, this.displayName, this.loggedIn = false});
}

class AuthController extends StateNotifier<AuthState> {
  final Api api;
  AuthController(this.api) : super(const AuthState(loading: true)) { restore(); }

  Future<void> restore() async {
    final token = await storage.read(key: 'jwt');
    if (token == null || token.isEmpty) { state = const AuthState(); return; }
    try {
      final me = await api.getMap('/users/me');
      state = AuthState(loggedIn: true, userEmail: '${me['email']}', displayName: '${me['displayName']}');
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await storage.delete(key: 'jwt');
        state = const AuthState();
      } else {
        // Offline restart: retain a previously authenticated account.
        final email = await storage.read(key: 'user_email');
        final name = await storage.read(key: 'display_name');
        state = email == null || email.isEmpty
          ? const AuthState()
          : AuthState(loggedIn: true, userEmail: email, displayName: name);
      }
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    await api.waitForServer();
    final body = await api.post('/auth/login', {'email': email.trim(), 'password': password});
    await _persist(body);
  }

  Future<void> register(String name, String email, String password) async {
    await api.waitForServer();
    final body = await api.post('/auth/register', {'displayName': name.trim(), 'email': email.trim(), 'password': password});
    await _persist(body);
  }

  Future<void> _persist(Map<String, dynamic> json) async {
    await storage.write(key: 'jwt', value: '${json['token']}');
    await storage.write(key: 'user_email', value: json['email'].toString().trim().toLowerCase());
    await storage.write(key: 'display_name', value: json['displayName'].toString());
    state = AuthState(loggedIn: true, userEmail: '${json['email']}', displayName: '${json['displayName']}');
  }

  Future<void> logout() async {
    await storage.delete(key: 'jwt');
    await storage.delete(key: 'user_email');
    await storage.delete(key: 'display_name');
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.read(apiProvider)),
);

final monthProvider = StateProvider<DateTime>((ref) {
  final today = DateTime.now();
  return DateTime(today.year, today.month);
});
String monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

final walletProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  final email=ref.read(authProvider).userEmail ?? '';
  try{
    final result=await ref.read(apiProvider).getList('/wallets');
    await OfflineQueue.rememberWallets(email,result);
    return result;
  }catch(_){
    final old=await OfflineQueue.wallets(email);
    if(old.isNotEmpty)return old;
    rethrow;
  }
});
final transactionProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  return ref.read(apiProvider).getList('/transactions');
});
final budgetProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  final month = monthKey(ref.watch(monthProvider));
  return ref.read(apiProvider).getList('/budgets?month=$month');
});
final summaryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  final month = monthKey(ref.watch(monthProvider));
  return ref.read(apiProvider).getMap('/reports/summary?month=$month');
});

void refreshData(WidgetRef ref) {
  ref.invalidate(walletProvider);
  ref.invalidate(transactionProvider);
  ref.invalidate(budgetProvider);
  ref.invalidate(summaryProvider);
}
), '');
    if (base.isEmpty) {
      throw TimeoutException('Bản ứng dụng chưa được cấu hình địa chỉ API.');
    }
    final healthClient = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      sendTimeout: const Duration(seconds: 6),
      headers: {'Accept': 'application/json'},
    ));
    try {
      for (var attempt = 0; attempt < 24; attempt++) {
        try {
          final response = await healthClient.get(base + '/actuator/health');
          final data = response.data;
          if (response.statusCode == 200 && data is Map && data['status'] == 'UP') {
            return;
          }
        } catch (_) {
          // A sleeping Render service may time out while starting.
        }
        if (attempt < 23) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    } finally {
      healthClient.close(force: true);
    }
    throw TimeoutException('Máy chủ MoneyMate chưa sẵn sàng sau khoảng hai phút. Hãy thử lại.');
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from((await dio.post(path, data: body)).data as Map);
  Future<List<Map<String, dynamic>>> getList(String path) async =>
      ((await dio.get(path)).data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<Map<String, dynamic>> getMap(String path) async =>
      Map<String, dynamic>.from((await dio.get(path)).data as Map);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from((await dio.put(path, data: body)).data as Map);
  Future<void> delete(String path) async { await dio.delete(path); }
}

final apiProvider = Provider<Api>((ref) => Api());

String apiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    final code = error.response?.statusCode;
    if (code == 401) return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.';
    if (code == 403) return 'Bạn không có quyền truy cập dữ liệu này.';
    if (code == 404) return 'Không tìm thấy dữ liệu được yêu cầu.';
    if (code == 409) return 'Dữ liệu đã tồn tại hoặc bị xung đột.';
    if (code != null && code >= 500) return 'Máy chủ đang bận. Thử lại sau.';
    if (code != null && code >= 400) return 'Yêu cầu không hợp lệ (HTTP $code).';
    return 'Không thể kết nối đến máy chủ. Kiểm tra Internet và API.';
  }
  return error.toString();
}

class AuthState {
  final bool loading;
  final String? userEmail;
  final String? displayName;
  final bool loggedIn;
  const AuthState({this.loading = false, this.userEmail, this.displayName, this.loggedIn = false});
}

class AuthController extends StateNotifier<AuthState> {
  final Api api;
  AuthController(this.api) : super(const AuthState(loading: true)) { restore(); }

  Future<void> restore() async {
    final token = await storage.read(key: 'jwt');
    if (token == null || token.isEmpty) { state = const AuthState(); return; }
    try {
      final me = await api.getMap('/users/me');
      state = AuthState(loggedIn: true, userEmail: '${me['email']}', displayName: '${me['displayName']}');
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await storage.delete(key: 'jwt');
        state = const AuthState();
      } else {
        // Offline restart: retain a previously authenticated account.
        final email = await storage.read(key: 'user_email');
        final name = await storage.read(key: 'display_name');
        state = email == null || email.isEmpty
          ? const AuthState()
          : AuthState(loggedIn: true, userEmail: email, displayName: name);
      }
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    final body = await api.post('/auth/login', {'email': email.trim(), 'password': password});
    await _persist(body);
  }

  Future<void> register(String name, String email, String password) async {
    final body = await api.post('/auth/register', {'displayName': name.trim(), 'email': email.trim(), 'password': password});
    await _persist(body);
  }

  Future<void> _persist(Map<String, dynamic> json) async {
    await storage.write(key: 'jwt', value: '${json['token']}');
    await storage.write(key: 'user_email', value: json['email'].toString().trim().toLowerCase());
    await storage.write(key: 'display_name', value: json['displayName'].toString());
    state = AuthState(loggedIn: true, userEmail: '${json['email']}', displayName: '${json['displayName']}');
  }

  Future<void> logout() async {
    await storage.delete(key: 'jwt');
    await storage.delete(key: 'user_email');
    await storage.delete(key: 'display_name');
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.read(apiProvider)),
);

final monthProvider = StateProvider<DateTime>((ref) {
  final today = DateTime.now();
  return DateTime(today.year, today.month);
});
String monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

final walletProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  final email=ref.read(authProvider).userEmail ?? '';
  try{
    final result=await ref.read(apiProvider).getList('/wallets');
    await OfflineQueue.rememberWallets(email,result);
    return result;
  }catch(_){
    final old=await OfflineQueue.wallets(email);
    if(old.isNotEmpty)return old;
    rethrow;
  }
});
final transactionProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  return ref.read(apiProvider).getList('/transactions');
});
final budgetProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  final month = monthKey(ref.watch(monthProvider));
  return ref.read(apiProvider).getList('/budgets?month=$month');
});
final summaryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authProvider.select((s) => '${s.loggedIn}:${s.userEmail}'));
  final month = monthKey(ref.watch(monthProvider));
  return ref.read(apiProvider).getMap('/reports/summary?month=$month');
});

void refreshData(WidgetRef ref) {
  ref.invalidate(walletProvider);
  ref.invalidate(transactionProvider);
  ref.invalidate(budgetProvider);
  ref.invalidate(summaryProvider);
}
