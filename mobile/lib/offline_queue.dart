import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';

class OfflineQueue {
  static Database? cachedDb;
  static const uuid=Uuid();
  static String owner(String email)=>email.trim().toLowerCase();
  static Future<Database> get db async {
    if(cachedDb!=null)return cachedDb!;
    cachedDb=await openDatabase(path.join(await getDatabasesPath(),'moneymate_outbox.db'),
      version:1,onCreate:(d,_)async{
        await d.execute('CREATE TABLE outbox (id TEXT PRIMARY KEY, owner TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, error TEXT)');
        await d.execute('CREATE TABLE wallets_cache (owner TEXT PRIMARY KEY, payload TEXT NOT NULL)');
      });
    return cachedDb!;
  }
  static Future<void> rememberWallets(String email,List<Map<String,dynamic>> entries)async{
    if(email.isEmpty)return;
    await (await db).insert('wallets_cache',{'owner':owner(email),'payload':jsonEncode(entries)},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }
  static Future<List<Map<String,dynamic>>> wallets(String email)async{
    final rows=await (await db).query('wallets_cache',where:'owner=?',whereArgs:[owner(email)]);
    if(rows.isEmpty)return [];
    return (jsonDecode(rows.first['payload'] as String) as List)
      .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  static Future<void> enqueue(String email,Map<String,dynamic> entry)async{
    await (await db).insert('outbox',{
      'id':uuid.v4(),'owner':owner(email),'payload':jsonEncode(entry),
      'created_at':DateTime.now().millisecondsSinceEpoch,
    });
  }
  static Future<List<Map<String,Object?>>> pending(String email)=>
    db.then((d)=>d.query('outbox',where:'owner=?',whereArgs:[owner(email)],orderBy:'created_at ASC'));
  static Future<int> count(String email)async=>(await pending(email)).length;
  static Future<void> deletePending(String email,String id)async{
    await (await db).delete('outbox',where:'id=? AND owner=?',whereArgs:[id,owner(email)]);
  }
  static String _friendlyError(int? code){
    if(code==null)return 'Mất mạng; sẽ thử lại khi có kết nối.';
    switch(code){
      case 400:return 'Dữ liệu không hợp lệ; kiểm tra giao dịch hoặc xóa bản chờ.';
      case 401:return 'Phiên đăng nhập hết hạn; đăng nhập lại rồi đồng bộ.';
      case 403:return 'Không có quyền truy cập ví này.';
      case 404:return 'Không tìm thấy ví; hãy kiểm tra tài khoản đang đăng nhập.';
      case 409:return 'Giao dịch bị xung đột; kiểm tra hoặc xóa bản chờ.';
      default:
        if(code>=500)return 'Máy chủ tạm thời gặp lỗi; sẽ thử lại sau.';
        return 'Máy chủ từ chối giao dịch (HTTP $code).';
    }
  }
  static Future<int> sync(String email,Api api)async{
    var synced=0;
    for(final draft in await pending(email)){
      final id=draft['id'] as String;
      final entry=Map<String,dynamic>.from(jsonDecode(draft['payload'] as String) as Map);
      try{
        await api.post('/transactions/offline-sync',{'clientId':id,'transaction':entry});
        await (await db).delete('outbox',where:'id=? AND owner=?',whereArgs:[id,owner(email)]);
        synced++;
      }on DioException catch(error){
        final code=error.response?.statusCode;
        await (await db).update('outbox',{'error':_friendlyError(code)},
          where:'id=? AND owner=?',whereArgs:[id,owner(email)]);
        // A missing network, expired session, or server outage blocks all later
        // sends. Permanent 4xx errors remain visible so the user can remove them.
        if(code==null || code==401 || code>=500)break;
      }
    }
    return synced;
  }
}
