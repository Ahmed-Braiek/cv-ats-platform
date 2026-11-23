import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../workspace/candidate_shell.dart';
import '../admin/admin_console_screen.dart';
import '../../ui/ats_design.dart';
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
          ? const _SignedInRoleGate(key: ValueKey('signed-in'))
          : const AuthScreen(key: ValueKey('authentication')),
    );
  }
}


/// Role selection is presentation-only. The administration Edge Function
/// independently validates the user's fresh server-side profile role on every
/// admin request; no role from user_metadata or local storage is trusted.
class _SignedInRoleGate extends StatefulWidget {
  const _SignedInRoleGate({super.key});
  @override State<_SignedInRoleGate> createState()=>_SignedInRoleGateState();
}
class _SignedInRoleGateState extends State<_SignedInRoleGate>{
  late Future<bool> admin;
  @override void initState(){super.initState();_reload();}
  void _reload(){
    admin=() async {
      final id=SupabaseConfig.client.auth.currentUser?.id;
      if(id==null)return false;
      final row=await SupabaseConfig.client.from('profiles')
        .select('role').eq('id',id).maybeSingle();
      return row?['role']=='admin';
    }();
  }
  @override Widget build(BuildContext context)=>FutureBuilder<bool>(
    future:admin,builder:(context,s){
      if(s.connectionState!=ConnectionState.done){
        return const Scaffold(body:SafeArea(child:Center(
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            CircularProgressIndicator(),
            SizedBox(height:16),
            Text('Opening your workspace…',
              style:TextStyle(color:AtsPalette.muted)),
          ]),
        )));
      }
      if(s.hasError){
        return Scaffold(body:SafeArea(child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:420),
          child:Padding(padding:const EdgeInsets.all(22),
            child:AtsEmptyState(icon:Icons.cloud_off_outlined,
              title:'Could not open your workspace',
              description:'Your account role could not be verified. '
                'Check your connection and try again.',
              action:FilledButton.icon(onPressed:()=>setState(_reload),
                icon:const Icon(Icons.refresh),label:const Text('Try again')))),
        ))));
      }
      return s.data==true?
        const AdminConsoleScreen(key:ValueKey('admin-workspace')):
        const CandidateShell(key:ValueKey('candidate-workspace'));
    },
  );
}
