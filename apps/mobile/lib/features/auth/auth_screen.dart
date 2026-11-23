import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../ui/ats_design.dart';

/// Sign-in and registration share visual language but remain distinct forms.
/// Confirmation email behavior follows the Supabase Auth project setting.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initiallyRegister = false});
  final bool initiallyRegister;
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  late bool registering;
  bool busy=false;
  bool showPassword=false;
  String? notice;
  bool confirmationPending=false;

  @override
  void initState(){super.initState();registering=widget.initiallyRegister;}
  @override
  void dispose(){email.dispose();password.dispose();name.dispose();super.dispose();}

  Future<void> _submit() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {busy=true;notice=null;});
    try {
      final auth=SupabaseConfig.client.auth;
      if(registering) {
        final response=await auth.signUp(
          email:email.text.trim(),
          password:password.text,
          data:{'display_name':name.text.trim()},
        );
        if(!mounted)return;
        if(response.session == null) {
          setState((){
            confirmationPending=true;
            notice='Check your email for a confirmation link, then return to sign in.';
          });
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        await auth.signInWithPassword(
          email:email.text.trim(),password:password.text);
        if(!mounted)return;
        Navigator.of(context).pop(true);
      }
    } on AuthException catch(error){
      if(mounted)setState(()=>notice=error.message);
    }catch(_){
      if(mounted)setState(()=>notice='Something went wrong. Check your connection and try again.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary=Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar:AppBar(title:const Text('CV ATS')),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:510),
        child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,26,22,40),
          child:Form(key:form,child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Align(alignment:Alignment.centerLeft,child:Container(
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:primary.withValues(alpha:.1),
                borderRadius:BorderRadius.circular(20)),
              child:Icon(Icons.lock_person_outlined,color:primary,size:32))),
            const SizedBox(height:24),
            const AtsEyebrow('SECURE CANDIDATE ACCOUNT'),
            const SizedBox(height:8),
            Text(registering?'Create your account':'Welcome back',
              style:Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight:FontWeight.w900,letterSpacing:-.5)),
            const SizedBox(height:8),
            Text(registering
              ?'Save CVs privately, keep your results and track your progress.'
              :'Sign in to view your analyses, documents and recommendations.',
              style:const TextStyle(color:AtsPalette.muted,height:1.5)),
            const SizedBox(height:25),
            AtsPanel(child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                if(registering)...[
                  TextFormField(
                    controller:name,autofillHints:const [AutofillHints.name],
                    decoration:const InputDecoration(
                      labelText:'Your name',prefixIcon:Icon(Icons.person_outline)),
                    maxLength:80),
                  const SizedBox(height:12),
                ],
                TextFormField(
                  controller:email,
                  keyboardType:TextInputType.emailAddress,
                  autofillHints:const [AutofillHints.email],
                  textInputAction:TextInputAction.next,
                  decoration:const InputDecoration(
                    labelText:'Email address',prefixIcon:Icon(Icons.email_outlined)),
                  validator:(v){
                    final t=v?.trim() ?? '';
                    return t.contains('@') && t.contains('.') ? null :
                      'Enter a valid email address';
                  },
                ),
                const SizedBox(height:15),
                TextFormField(
                  controller:password,
                  obscureText:!showPassword,
                  autofillHints:[registering
                    ?AutofillHints.newPassword:AutofillHints.password],
                  decoration:InputDecoration(
                    labelText:'Password',
                    prefixIcon:const Icon(Icons.lock_outline),
                    suffixIcon:IconButton(
                      tooltip:showPassword?'Hide password':'Show password',
                      onPressed:()=>setState(()=>showPassword=!showPassword),
                      icon:Icon(showPassword?Icons.visibility_off_outlined:
                        Icons.visibility_outlined)),
                  ),
                  validator:(v)=>(v?.length ?? 0)>=8?null:
                    'Use at least 8 characters',
                  onFieldSubmitted:(_)=>_submit(),
                ),
                if(!registering) Align(
                  alignment:Alignment.centerRight,
                  child:TextButton(
                    onPressed:busy?null:()=>Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:(_)=>const ForgotPasswordPage())),
                    child:const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height:12),
                if(notice!=null)...[
                  Container(
                    padding:const EdgeInsets.all(13),
                    decoration:BoxDecoration(
                      color:(confirmationPending?AtsPalette.success:AtsPalette.danger)
                        .withValues(alpha:.09),
                      borderRadius:BorderRadius.circular(12)),
                    child:Row(children:[
                      Icon(confirmationPending?Icons.mark_email_read_outlined:
                        Icons.info_outline,size:20,
                        color:confirmationPending?AtsPalette.success:
                          AtsPalette.danger),
                      const SizedBox(width:10),
                      Expanded(child:Text(notice!,
                        style:const TextStyle(fontSize:12,height:1.4))),
                    ]),
                  ),
                  const SizedBox(height:16),
                ],
                if(!SupabaseConfig.configured)...[
                  const Text('Supabase is not configured. Add a public publishable key to your Flutter launch settings.',
                    style:TextStyle(color:AtsPalette.danger,fontSize:12)),
                  const SizedBox(height:12),
                ],
                FilledButton(
                  onPressed:busy||!SupabaseConfig.configured?null:_submit,
                  child:busy
                    ?const SizedBox(height:22,width:22,
                      child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                    :Text(registering?'Create account':'Sign in securely'),
                ),
                const SizedBox(height:12),
                OutlinedButton(
                  onPressed:busy?null:()=>setState((){
                    registering=!registering;
                    notice=null;confirmationPending=false;
                  }),
                  child:Text(registering
                    ?'Already a member? Sign in':'New to CV ATS? Create an account'),
                ),
              ]),
            ),
            const SizedBox(height:18),
            const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              Icon(Icons.shield_outlined,size:17,color:AtsPalette.success),
              SizedBox(width:7),
              Flexible(child:Text('Your documents are private to your account.',
                style:TextStyle(color:AtsPalette.muted,fontSize:12))),
            ]),
          ]))),
      ))),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override State<ForgotPasswordPage> createState()=>_ForgotPasswordPageState();
}
class _ForgotPasswordPageState extends State<ForgotPasswordPage>{
  final email=TextEditingController();
  bool busy=false,sent=false;
  String? error;
  @override void dispose(){email.dispose();super.dispose();}
  Future<void> send()async{
    if(!email.text.contains('@') || busy)return;
    setState((){busy=true;error=null;});
    try{
      await SupabaseConfig.client.auth.resetPasswordForEmail(email.text.trim());
      if(mounted)setState(()=>sent=true);
    }catch(_){
      if(mounted)setState(()=>error='Could not send recovery instructions. Please try again.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }
  @override Widget build(BuildContext context)=>AtsPage(
    title:'Password recovery',
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsHeader(title:'Reset your password',
        subtitle:'We will send recovery instructions to your account email.'),
      AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        TextField(controller:email,
          keyboardType:TextInputType.emailAddress,
          decoration:const InputDecoration(labelText:'Account email',
            prefixIcon:Icon(Icons.mail_outline))),
        const SizedBox(height:16),
        if(sent)const Text('If the account exists, a recovery email has been sent. Follow its instructions.',
          style:TextStyle(color:AtsPalette.success)),
        if(error!=null)Text(error!,
          style:const TextStyle(color:AtsPalette.danger)),
        FilledButton(onPressed:busy||sent?null:send,
          child:Text(busy?'Sending...':'Send recovery email')),
      ])),
      const SizedBox(height:16),
      const Text('Important: Android password-reset deep linking must be configured before release.',
        style:TextStyle(color:AtsPalette.muted,fontSize:12)),
    ]),
  );
}
