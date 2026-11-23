import 'package:flutter/material.dart';

import 'config/supabase_config.dart';
import 'features/analysis/analysis_api.dart';
import 'features/analysis/analysis_status_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/session_gate.dart';
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
        home:const SessionGate(),
      ),
    );
  }
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
  bool _uploadFailed = false;
  String? _uploadedCvId;
  String? _uploadedFile;
  String? _uploadMessage;

  @override void initState() {
    super.initState();
    _jobDescription.addListener(() { if (mounted) setState(() {}); });
  }

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
    setState(() { _uploading = true; _uploadFailed = false; _uploadMessage = null; });
    try {
      final uploaded = await CvUploadService.pickAndUpload();
      if (!mounted || uploaded == null) return;
      setState(() {
        _uploadedCvId = uploaded.id;
        _uploadedFile = uploaded.name;
        _uploadFailed = false;
        _uploadMessage = null;
      });
    } catch (_) {
      if (mounted) setState(() { _uploadFailed = true;
        _uploadMessage = 'We could not upload this CV. Check the file and your connection, then retry.'; });
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
    setState(() { _submitting = true; _uploadFailed = false; _uploadMessage = null; });
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
          const Flexible(child:_StepBadge(number:'1',label:'Your CV',active:true)),
          const SizedBox(width:6),
          SizedBox(width:22,child:Divider(color:onSurface.withValues(alpha:.15))),
          const SizedBox(width:6),
          Flexible(child:_StepBadge(number:'2',label:'Job details',
            active:_jobDescription.text.trim().length>=20)),
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
            onTap:_uploading||_submitting?null:_pickCv,
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
                Text(_uploadedFile??'Choose your CV to get started',
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  textAlign:TextAlign.center,
                  style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
                const SizedBox(height:8),
                Text('PDF, DOCX, PNG or JPG · 10 MB maximum',
                  style:TextStyle(fontSize:12,
                    color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.68))),
                const SizedBox(height:14),
                if(_uploading)...[
                  const LinearProgressIndicator(minHeight:5),
                  const SizedBox(height:10),
                  Text('Checking format and storing your CV securely…',
                    textAlign:TextAlign.center,
                    style:TextStyle(fontSize:12,
                      color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.72))),
                ],
                if(!_uploading)Text(_uploadedCvId!=null
                  ?'Replace uploaded CV':_uploadFailed?'Retry CV upload':'Browse files',
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
        if(_uploading || _submitting)...[
          const SizedBox(height:15),
          AtsInfoStrip(icon:_uploading?Icons.file_upload_outlined:Icons.lock_clock_outlined,
            message:_uploading?'Validating your file and uploading privately.':
              'Creating the request and contacting the AI processor.'),
        ],
        if(_uploadMessage!=null)...[
          const SizedBox(height:15),
          AtsInfoStrip(icon:_uploadFailed?Icons.error_outline_rounded:
            Icons.info_outline_rounded,message:_uploadMessage!,warning:_uploadFailed),
        ],
        const SizedBox(height:22),
        if(_uploadedCvId!=null)Padding(
          padding:const EdgeInsets.only(bottom:15),
          child:AtsInfoStrip(icon:Icons.verified_user_outlined,
            message:!analysisEnabled
              ?'Your CV was uploaded securely, but analysis is disabled in this build.'
              :_jobDescription.text.trim().length>=20
                ?'Ready to analyze. Your private CV and job posting will be '
                  'compared against real evidence.'
                :'CV uploaded privately. Add the original job description '
                  'to start an evidence-based comparison.')),
        SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:_uploadedCvId==null || _uploading || _submitting ||
              _jobDescription.text.trim().length<20 || !analysisEnabled
            ?null:_submitAnalysis,
          icon:Icon(_submitting?Icons.hourglass_top_rounded:Icons.auto_awesome_rounded),
          label:Text(_submitting?'Submitting securely...':'Analyze my application'),
        )),
        const SizedBox(height:12),
        Text(analysisEnabled
          ?'Your request enters a secure queue. Results appear when processing finishes.'
          :'This build has analysis disabled. Install the latest CV-ATS build to submit a job.',
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
    Flexible(child:Text(label,maxLines:2,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
  ]);
}
