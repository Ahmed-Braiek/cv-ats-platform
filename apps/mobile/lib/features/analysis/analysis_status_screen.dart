import 'dart:async';

import 'package:flutter/material.dart';
import '../../ui/ats_design.dart';
import 'analysis_api.dart';
import 'analysis_report_screen.dart';

/// Status polling + dedicated ATS, Job Match and Recommendation sections.
/// No scores appear until the backend confirms completed persisted results.
class AnalysisStatusScreen extends StatefulWidget {
  const AnalysisStatusScreen({super.key,required this.analysisId});
  final String analysisId;
  @override State<AnalysisStatusScreen> createState()=>_AnalysisStatusScreenState();
}

class _AnalysisStatusScreenState extends State<AnalysisStatusScreen> {
  Timer? timer;
  Map<String,dynamic>? payload;
  String? error;
  bool refreshing=false;
  bool restarting=false;

  String _diagnostic(String? code) {
    switch(code){
      case 'cv_evidence_insufficient':
      case 'invalid_cv_json':
      case 'empty_docx':
        return 'We could not extract enough reliable CV text. Try a text-based PDF or DOCX.';
      case 'job_requirements_not_grounded':
      case 'invalid_job_json':
      case 'no_job_requirements':
        return 'The job requirements could not be verified. Paste the complete posting and try a new analysis.';
      case 'rate_limited':
        return 'The analysis provider is currently at capacity. Please try a new analysis later.';
      case 'gemini_config_error':
      case 'gemini_not_configured':
        return 'The AI service configuration needs attention. Please contact support.';
      case 'result_save_failed':
        return 'The results could not be saved securely. Please try again.';
      default:
        return 'This analysis could not finish. Please check the input and try again.';
    }
  }

  Future<void> _tryStart() async {
    if(restarting)return;
    setState(() { restarting=true; error=null; });
    final ok=await AnalysisApi.startProcessing(widget.analysisId);
    if(!mounted)return;
    setState(() { restarting=false;
      if(!ok)error='The processor did not start. Check the service configuration and retry.';
    });
    if(ok) await _refresh();
  }

  @override void initState() {
    super.initState();
    _refresh();
    timer=Timer.periodic(const Duration(seconds:5),(_)=>_refresh());
  }

  Future<void> _refresh() async {
    if(refreshing)return;
    refreshing=true;
    try{
      final data=await AnalysisApi.results(widget.analysisId);
      if(!mounted)return;
      setState((){payload=data;error=null;});
      final status=(data['analysis'] as Map<String,dynamic>?)?['status'];
      if(data['ready']==true || ['failed','expired','cancelled'].contains(status))
        timer?.cancel();
    }catch(_){
      if(mounted)setState(()=>error='Unable to load the latest analysis status.');
    }finally{refreshing=false;}
  }

  @override void dispose(){timer?.cancel();super.dispose();}

  @override Widget build(BuildContext context) {
    final ready=payload?['ready']==true;
    final analysis=payload?['analysis'] as Map<String,dynamic>?;
    final status=(analysis?['status'] as String?) ?? 'queued';
    final failed=['failed','expired','cancelled'].contains(status);
    if(!ready)return AtsPage(title:'CV analysis',actions:[
      IconButton(tooltip:'Refresh status',
        onPressed:_refresh,icon:const Icon(Icons.refresh_rounded)),
    ],child:Column(children:[
      const SizedBox(height:23),
      Container(padding:const EdgeInsets.all(21),
        decoration:BoxDecoration(
          color:AtsPalette.brand.withValues(alpha:.09),
          shape:BoxShape.circle),
        child:Icon(failed
          ?Icons.error_outline:Icons.hourglass_top_rounded,
          color:Theme.of(context).colorScheme.primary,size:45)),
      const SizedBox(height:22),
      Text(['failed','cancelled','expired'].contains(status)
        ?'Analysis did not finish':'Analyzing your application',
        textAlign:TextAlign.center,
        style:Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      const Text('Your CV and the job requirements are processed in a secure queue.',
        textAlign:TextAlign.center,
        style:TextStyle(color:AtsPalette.muted,height:1.5)),
      const SizedBox(height:25),
      AtsPanel(child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          const Text('Current status',style:TextStyle(fontWeight:FontWeight.w800)),
          AtsStatusChip(value:status),
        ]),
        const SizedBox(height:18),
        if(!['failed','cancelled','expired'].contains(status))
          const LinearProgressIndicator(minHeight:7),
        const SizedBox(height:13),
        Text(error ?? (failed
          ?_diagnostic(analysis?['failure_code'] as String?)
          :status=='queued'
            ?'Queued. If processing has not started, use Start processing below.'
            :'This screen refreshes automatically while processing.'),
          style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
      ])),
      const SizedBox(height:18),
      if(status=='queued') FilledButton.icon(onPressed:restarting?null:_tryStart,
        icon:const Icon(Icons.play_arrow_rounded),
        label:Text(restarting?'Starting...':'Start processing')),
      const SizedBox(height:10),
      OutlinedButton.icon(onPressed:_refresh,
        icon:const Icon(Icons.refresh_rounded),label:const Text('Refresh status')),
      const SizedBox(height:22),
      const Text('AI suggestions are informational. Never add skills you do not have.',
        textAlign:TextAlign.center,
        style:TextStyle(fontSize:12,color:AtsPalette.muted)),
    ]));

    return AnalysisReportScreen(payload: payload!);
  }
}
