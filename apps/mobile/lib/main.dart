import 'package:flutter/material.dart';

import 'config/supabase_config.dart';
import 'features/analysis/analysis_api.dart';
import 'features/analysis/analysis_status_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/workspace/candidate_shell.dart';
import 'ui/ats_design.dart';
import 'features/cv/cv_upload_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const CvAtsApp());
}

class CvAtsApp extends StatelessWidget {
  const CvAtsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AtsAppearance.mode,
      builder:(context, mode, _) => MaterialApp(
        title:'CV ATS • Career insights',
        debugShowCheckedModeBanner:false,
        theme:AtsTheme.light(),
        darkTheme:AtsTheme.dark(),
        themeMode:mode,
        home:const LandingScreen(),
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState()=>_LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  Future<void> _openAuth() async {
    if(!SupabaseConfig.configured){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Configure the public Supabase key to sign in.')));
      return;
    }
    final ok=await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder:(_)=>const AuthScreen()));
    if(!mounted)return;
    if(ok == true) _openWorkspace();
  }

  void _openWorkspace() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder:(_)=>const CandidateShell()));

  @override
  Widget build(BuildContext context) {
    final signedIn=SupabaseConfig.configured &&
      SupabaseConfig.client.auth.currentUser!=null;
    final dark=Theme.of(context).brightness==Brightness.dark;
    final text=Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar:AppBar(title:Row(mainAxisSize:MainAxisSize.min,children:[
        Container(
          padding:const EdgeInsets.all(7),
          decoration:BoxDecoration(color:AtsPalette.brand,
            borderRadius:BorderRadius.circular(9)),
          child:const Icon(Icons.layers_rounded,size:18,color:Colors.white)),
        const SizedBox(width:8),
        const Text('CV ATS'),
      ]),actions:[
        TextButton(
          onPressed:signedIn?_openWorkspace:_openAuth,
          child:Text(signedIn?'My workspace':'Sign in')),
        const SizedBox(width:8),
      ]),
      body:SafeArea(child:Align(alignment:Alignment.topCenter,
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:920),
          child:ListView(padding:const EdgeInsets.fromLTRB(20,25,20,36),children:[
            Row(children:[
              Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),
                decoration:BoxDecoration(
                  color:AtsPalette.ocean.withValues(alpha:.12),
                  borderRadius:BorderRadius.circular(40)),
                child:const Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(Icons.bolt_rounded,size:15,color:AtsPalette.success),
                  SizedBox(width:5),
                  Text('MAKE YOUR NEXT APPLICATION STRONGER',
                    style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,
                      color:AtsPalette.success,letterSpacing:.45)),
                ]),
              ),
            ]),
            const SizedBox(height:24),
            Text('Know how your CV\nperforms before\nyou apply.',
              style:Theme.of(context).textTheme.displaySmall?.copyWith(
                height:1.13,fontWeight:FontWeight.w900,
                letterSpacing:-1.5,color:text)),
            const SizedBox(height:16),
            Text('See what automated systems can read, how well your CV covers a job description, and what you can improve — without inventing experience.',
              style:TextStyle(height:1.55,fontSize:16,
                color:text.withValues(alpha:.66))),
            const SizedBox(height:24),
            FilledButton.icon(
              onPressed:()=>Navigator.of(context).push(
                MaterialPageRoute<void>(builder:(_)=>const NewAnalysisScreen())),
              icon:const Icon(Icons.upload_file_rounded),
              label:const Text('Analyze my CV'),
            ),
            const SizedBox(height:10),
            OutlinedButton.icon(
              onPressed:signedIn?_openWorkspace:_openAuth,
              icon:Icon(signedIn?Icons.grid_view_rounded:Icons.login_rounded),
              label:Text(signedIn?'Open workspace':'Sign in / create account')),
            const SizedBox(height:24),
            Container(
              padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(
                gradient:const LinearGradient(
                  colors:[AtsPalette.midnight,Color(0xFF284D91)],
                  begin:Alignment.topLeft,end:Alignment.bottomRight),
                borderRadius:BorderRadius.circular(23)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const AtsEyebrow('YOUR PERSONAL INSIGHT SPACE',
                  color:Color(0xFF82E6F1)),
                const SizedBox(height:16),
                const Text('Two scores. Two different questions.',
                  style:TextStyle(color:Colors.white,
                    fontSize:21,fontWeight:FontWeight.w900)),
                const SizedBox(height:16),
                for(final entry in <(String,String,double)>[
                  ('ATS compatibility','Can software understand your CV?',.7),
                  ('Job Match','Does your CV show the skills requested?',.55),
                ]) Padding(padding:const EdgeInsets.only(bottom:15),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(entry.$1,style:const TextStyle(
                      fontWeight:FontWeight.w700,color:Colors.white)),
                    const SizedBox(height:5),
                    Text(entry.$2,style:const TextStyle(
                      color:Color(0xFFC5D7F2),fontSize:12)),
                    const SizedBox(height:9),
                    ClipRRect(borderRadius:BorderRadius.circular(10),
                      child:LinearProgressIndicator(
                        value:entry.$3,minHeight:7,
                        backgroundColor:Colors.white12,
                        valueColor:AlwaysStoppedAnimation<Color>(
                          entry.$1=='Job Match'?AtsPalette.ocean:
                            const Color(0xFF88A5FF)))),
                  ])),
                const Text('Illustration only — no personal results shown.',
                  style:TextStyle(color:Color(0xFFAEC4DF),fontSize:11)),
              ]),
            ),
            const SizedBox(height:28),
            const AtsSectionTitle('What you will discover',
              subtitle:'Clear feedback, organized into focused sections'),
            const SizedBox(height:14),
            const FeatureCard(icon:Icons.verified_outlined,
              title:'ATS compatibility',
              subtitle:'Sections, parsing readiness and clear document structure.'),
            const SizedBox(height:10),
            const FeatureCard(icon:Icons.track_changes_rounded,
              title:'Job Match',
              subtitle:'Visible skill coverage versus the job requirements.'),
            const SizedBox(height:10),
            const FeatureCard(icon:Icons.lightbulb_outline,
              title:'Actionable recommendations',
              subtitle:'Specific, honest improvements based on your CV evidence.'),
            const SizedBox(height:18),
            Center(child:Text(
              'Built for thoughtful career preparation. Not a hiring prediction.',
              textAlign:TextAlign.center,style:TextStyle(
                color:dark?Colors.white54:AtsPalette.muted,fontSize:12))),
          ]),
        ))),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({super.key,required this.icon,required this.title,
    required this.subtitle});
  final IconData icon;
  final String title,subtitle;
  @override
  Widget build(BuildContext context)=>AtsPanel(
    child:Row(children:[
      Container(padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(
          color:AtsPalette.brand.withValues(alpha:.09),
          borderRadius:BorderRadius.circular(15)),
        child:Icon(icon,color:AtsPalette.brand,size:25)),
      const SizedBox(width:16),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(
          fontSize:16,fontWeight:FontWeight.w800)),
        const SizedBox(height:6),
        Text(subtitle,style:const TextStyle(
          height:1.45,color:AtsPalette.muted,fontSize:13)),
      ])),
      const Icon(Icons.chevron_right_rounded,color:AtsPalette.muted),
    ]),
  );
}

class NewAnalysisScreen extends StatefulWidget {
  const NewAnalysisScreen({super.key});

  @override
  State<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends State<NewAnalysisScreen> {
  final _jobDescription = TextEditingController();
  final _jobTitle = TextEditingController();
  static const analysisEnabled = bool.fromEnvironment('CV_ATS_ANALYSIS_ENABLED', defaultValue:false);
  bool _uploading = false;
  bool _submitting = false;
  String? _uploadedCvId;
  String? _uploadedFile;
  String? _uploadMessage;

  Future<void> _pickCv() async {
    if (_uploading) return;
    if (!SupabaseConfig.configured) {
      setState(() => _uploadMessage = 'Configure Supabase to enable private upload.');
      return;
    }
    if (SupabaseConfig.client.auth.currentUser == null) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
      );
      if (!mounted || loggedIn != true) return;
    }
    setState(() { _uploading = true; _uploadMessage = null; });
    try {
      final uploaded = await CvUploadService.pickAndUpload();
      if (!mounted || uploaded == null) return;
      setState(() {
        _uploadedCvId = uploaded.id;
        _uploadedFile = uploaded.name;
        _uploadMessage = 'CV uploaded privately. Add a job description to continue.';
      });
    } catch (error) {
      if (mounted) setState(() => _uploadMessage = 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }


  Future<void> _submitAnalysis() async {
    if (_uploadedCvId == null || _submitting) return;
    if (_jobDescription.text.trim().length < 20) {
      setState(() => _uploadMessage = 'Enter at least 20 characters for the job description.');
      return;
    }
    setState(() { _submitting = true; _uploadMessage = null; });
    try {
      final id = await AnalysisApi.submit(
        cvId: _uploadedCvId!,
        jobDescription: _jobDescription.text.trim(),
        jobTitle: _jobTitle.text.trim(),
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AnalysisStatusScreen(analysisId: id),
      ));
    } catch (_) {
      if (mounted) setState(() => _uploadMessage =
        'Unable to start the analysis. Check your connection, plan quota and API configuration.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _jobDescription.dispose();
    _jobTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface=Theme.of(context).colorScheme.onSurface;
    return AtsPage(
      title:'New analysis',
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const AtsEyebrow('STEP BY STEP'),
        const SizedBox(height:10),
        Text('Analyze your application',
          style:Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        Text('Two simple inputs. Two different insights.',
          style:TextStyle(color:onSurface.withValues(alpha:.65))),
        const SizedBox(height:25),
        Row(children:[
          _StepBadge(number:'1',label:'Your CV',active:true),
          const SizedBox(width:9),
          Expanded(child:Divider(color:onSurface.withValues(alpha:.15))),
          const SizedBox(width:9),
          const _StepBadge(number:'2',label:'Job details',active:false),
        ]),
        const SizedBox(height:24),
        const AtsSectionTitle('Upload your CV',
          subtitle:'Start with the document you plan to send.'),
        const SizedBox(height:12),
        Material(
          color:Theme.of(context).colorScheme.surface,
          clipBehavior:Clip.antiAlias,
          borderRadius:BorderRadius.circular(20),
          child:InkWell(
            onTap:_uploading?null:_pickCv,
            child:Container(
              width:double.infinity,
              padding:const EdgeInsets.fromLTRB(20,28,20,28),
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),
                border:Border.all(color:_uploadedCvId != null
                  ?AtsPalette.success:AtsPalette.brand.withValues(alpha:.55),
                  width:1.5)),
              child:Column(children:[
                Container(padding:const EdgeInsets.all(16),
                  decoration:BoxDecoration(
                    color:(_uploadedCvId!=null?AtsPalette.success:AtsPalette.brand)
                      .withValues(alpha:.1),shape:BoxShape.circle),
                  child:Icon(_uploadedCvId!=null
                    ?Icons.check_circle_rounded:Icons.upload_file_rounded,
                    color:_uploadedCvId!=null?AtsPalette.success:AtsPalette.brand,
                    size:32)),
                const SizedBox(height:13),
                Text(_uploadedFile??'Tap to choose your CV',
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  textAlign:TextAlign.center,
                  style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
                const SizedBox(height:8),
                const Text('PDF, DOCX, PNG or JPG · 10 MB maximum',
                  style:TextStyle(fontSize:12,color:AtsPalette.muted)),
                const SizedBox(height:14),
                if(_uploading)const LinearProgressIndicator(),
                if(!_uploading)Text(_uploadedCvId!=null
                  ?'Change file':'Choose a file from your device',
                  style:const TextStyle(color:AtsPalette.brand,
                    fontWeight:FontWeight.w700)),
              ]),
            ),
          ),
        ),
        const SizedBox(height:10),
        const Row(children:[
          Icon(Icons.lock_outline,color:AtsPalette.success,size:17),
          SizedBox(width:7),
          Expanded(child:Text(
            'Stored privately in your account. Sign-in is required for upload.',
            style:TextStyle(color:AtsPalette.muted,fontSize:12))),
        ]),
        const SizedBox(height:25),
        const AtsSectionTitle('Describe the role',
          subtitle:'Paste the original description to compare relevant requirements.'),
        const SizedBox(height:13),
        AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          TextField(controller:_jobTitle,textInputAction:TextInputAction.next,
            decoration:const InputDecoration(
              prefixIcon:Icon(Icons.work_outline_rounded),
              labelText:'Job title (optional)',
              hintText:'e.g. Junior Flutter Developer')),
          const SizedBox(height:13),
          TextField(controller:_jobDescription,
            minLines:7,maxLines:12,maxLength:16000,
            decoration:const InputDecoration(
              labelText:'Job description',
              alignLabelWithHint:true,
              hintText:'Paste duties, required skills, experience and qualifications…')),
          const SizedBox(height:7),
          const Text('We only compare requirements explicitly present in the description.',
            style:TextStyle(color:AtsPalette.muted,fontSize:12)),
        ])),
        if(_uploadMessage!=null)...[
          const SizedBox(height:15),
          AtsPanel(padding:const EdgeInsets.all(14),child:Row(children:[
            const Icon(Icons.info_outline,color:AtsPalette.brand,size:19),
            const SizedBox(width:9),
            Expanded(child:Text(_uploadMessage!,
              style:const TextStyle(fontSize:12,height:1.4))),
          ])),
        ],
        const SizedBox(height:22),
        FilledButton.icon(
          onPressed:_uploadedCvId==null || _submitting || !analysisEnabled
            ?null:_submitAnalysis,
          icon:Icon(_submitting?Icons.hourglass_top:Icons.auto_awesome),
          label:Text(_submitting?'Submitting securely...':'Analyze my application'),
        ),
        const SizedBox(height:12),
        Text(analysisEnabled
          ?'Your request enters a secure queue. Results appear when processing finishes.'
          :'Live analysis will be enabled after the Gemini worker and end-to-end tests are verified.',
          textAlign:TextAlign.center,
          style:const TextStyle(color:AtsPalette.muted,fontSize:12,height:1.4)),
      ]),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number,required this.label,required this.active});
  final String number,label;
  final bool active;
  @override Widget build(BuildContext context)=>Row(children:[
    CircleAvatar(radius:16,
      backgroundColor:active?AtsPalette.brand:AtsPalette.brand.withValues(alpha:.1),
      child:Text(number,style:TextStyle(
        fontWeight:FontWeight.w800,color:active?Colors.white:AtsPalette.brand))),
    const SizedBox(width:6),
    Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
  ]);
}
