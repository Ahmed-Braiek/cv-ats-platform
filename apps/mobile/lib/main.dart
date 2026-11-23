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
        _uploadMessage = 'CV securely uploaded. AI analysis is not available yet.';
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
    return PageShell(
      title: 'New analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analyze your application',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Upload your CV and add a job description.',
              style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 22),
          InkWell(
            onTap: _uploading ? null : _pickCv,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF93C5FD), width: 2),
              ),
              child: Column(children: [
                const Icon(Icons.upload_file_rounded, size: 48, color: CvAtsApp.primary),
                const SizedBox(height: 12),
                Text(_uploadedFile ?? 'Choose a CV', style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 8),
                const Text('PDF, DOCX, PNG or JPG • up to 10 MB',
                  style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                Text(_uploading ? 'Uploading securely...' : 'Tap to select and upload your CV',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
          if (_uploadMessage != null) ...[
            const SizedBox(height: 12),
            Text(_uploadMessage!, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 22),
          TextField(
            controller: _jobTitle,
            decoration: const InputDecoration(labelText: 'Job title (optional)'),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _jobDescription,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Job description', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          const Text('Upload a CV, enter a real job description, then submit it for processing by the backend. Processing requires the deployed API and Gemini worker.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_uploadedCvId == null || _submitting) ? null : _submitAnalysis,
            child: Text(_submitting ? 'Submitting...' : 'Analyze my application'),
          ),
        ],
      ),
    );
  }
}
