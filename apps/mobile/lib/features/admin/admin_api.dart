import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';

/// All administrative operations require Supabase Auth + fresh server-side
/// profiles.role='admin'. No privileged keys are present in Flutter.
class AdminApi {
  static Future<dynamic> call(String action, [Map<String,dynamic> args = const {}]) async {
    if (!SupabaseConfig.configured ||
        SupabaseConfig.client.auth.currentSession == null) {
      throw StateError('Sign in to access administration.');
    }
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'admin-console', body: {'action':action, ...args},
      );
      if (res.status < 200 || res.status >= 300) {
        throw StateError('Admin service returned ${res.status}.');
      }
      final data = res.data;
      if (data is! Map || data['data'] == null) {
        throw StateError('Unexpected response from administration.');
      }
      return data['data'];
    } on FunctionException catch (error) {
      final status = error.status;
      if (status == 401 || status == 403) {
        throw StateError('Administrator access required. Sign in with an approved admin account.');
      }
      throw StateError('Admin request failed (${status ?? 'network'}). Please retry.');
    }
  }

  static Map<String,dynamic> object(dynamic input) =>
      input is Map ? Map<String,dynamic>.from(input) : <String,dynamic>{};
  static List<Map<String,dynamic>> rows(dynamic input) => input is List
      ? input.whereType<Map>().map((row)=>Map<String,dynamic>.from(row)).toList()
      : <Map<String,dynamic>>[];
}
