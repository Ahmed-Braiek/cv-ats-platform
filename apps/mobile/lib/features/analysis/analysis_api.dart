import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/supabase_config.dart';

class AnalysisApi {
  static const baseUrl = String.fromEnvironment('CV_ATS_API_URL');
  static String get _token {
    final token = SupabaseConfig.client.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Sign in to submit an analysis');
    return token;
  }
  static void _validate() {
    if (baseUrl.isEmpty || !baseUrl.startsWith('https://') &&
        !baseUrl.startsWith('http://10.0.2.2:')) {
      throw StateError('Configure a HTTPS backend API URL');
    }
  }
  /// Starts a bounded Supabase Edge background task after the NestJS API has
  /// committed the analysis. Feature-gated until Gemini credentials are ready.
  static Future<bool> startProcessing(String analysisId) async {
    const enabled = bool.fromEnvironment('CV_ATS_ANALYSIS_ENABLED',
        defaultValue: false);
    if (!enabled || !SupabaseConfig.configured) return false;
    try {
      final result = await SupabaseConfig.client.functions.invoke(
        'process-cv', body: {'analysisId': analysisId},
      );
      return result.status == 202;
    } catch (_) {
      return false; // Job stays queued; never fabricate completed results.
    }
  }

  static Future<String> submit({
    required String cvId,
    required String jobDescription,
    String? jobTitle,
  }) async {
    _validate();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/analyses'),
      headers: {'Content-Type':'application/json','Authorization':'Bearer $_token'},
      body: jsonEncode({
        'cvId':cvId,
        'jobDescription':jobDescription,
        'jobTitle':jobTitle,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError('Submission failed (${response.statusCode})');
    }
    final result=jsonDecode(response.body) as Map<String,dynamic>;
    final id = (result['data'] as Map<String,dynamic>)['id'] as String;
    await startProcessing(id);
    return id;
  }
  static Future<Map<String,dynamic>> results(String id) async {
    _validate();
    final response=await http.get(
      Uri.parse('$baseUrl/v1/analyses/$id/results'),
      headers:{'Authorization':'Bearer $_token'},
    ).timeout(const Duration(seconds:20));
    if (response.statusCode != 200) {
      throw StateError('Unable to load analysis (${response.statusCode})');
    }
    final json=jsonDecode(response.body) as Map<String,dynamic>;
    return json['data'] as Map<String,dynamic>;
  }
}
