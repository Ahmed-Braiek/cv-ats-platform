import 'package:supabase_flutter/supabase_flutter.dart';

/// Public project metadata only. Never place service_role or Gemini secrets here.
class SupabaseConfig {
  static const projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uqtyxhkevnyjvhwdgkyh.supabase.co',
  );
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get configured => publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!configured) return; // Allows offline widget tests / Figma preview.
    await Supabase.initialize(
      url: projectUrl,
      anonKey: publishableKey,
    );
  }

  static SupabaseClient get client {
    if (!configured) {
      throw StateError('Missing SUPABASE_PUBLISHABLE_KEY build configuration');
    }
    return Supabase.instance.client;
  }
}
