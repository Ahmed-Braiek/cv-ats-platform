import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../workspace/candidate_shell.dart';
import 'auth_screen.dart';

/// The app opens straight into authentication unless a valid session exists.
/// Supabase emits events when login, OTP verification or sign-out completes.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.configured) {
      _subscription = SupabaseConfig.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = SupabaseConfig.configured &&
        SupabaseConfig.client.auth.currentSession != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      child: isSignedIn
          ? const CandidateShell(key: ValueKey('candidate'))
          : const AuthScreen(key: ValueKey('authentication')),
    );
  }
}
