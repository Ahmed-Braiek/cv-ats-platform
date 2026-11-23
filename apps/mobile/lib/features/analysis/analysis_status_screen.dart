import 'dart:async';
import 'package:flutter/material.dart';

import '../../ui/ats_design.dart';
import 'analysis_api.dart';
import 'analysis_report_screen.dart';

class AnalysisStatusScreen extends StatefulWidget{
  const AnalysisStatusScreen({super.key,required this.analysisId});
  final String analysisId;
  @override State<AnalysisStatusScreen> createState()=>_AnalysisStatusScreenState();
}
class _AnalysisStatusScreenState extends State<AnalysisStatusScreen>{
  Timer? timer;
  Map<String,dynamic>? payload;
  String? error;
  bool refreshing=false,restarting=false;
  static const phases=[
    ('queued','Document received','Your CV and job posting are stored privately.',Icons.lock_outline_rounded),
    ('extracting','Reading the CV','Extracting experiences, projects, education and readable text.',Icons.document_scanner_outlined),
    ('parsing_job','Understanding the vacancy','Identifying explicit job requirements and qualifications.',Icons.work_outline_rounded),
    ('scoring','Checking the evidence','Comparing direct and transferable skills with real CV evidence.',Icons.fact_check_outlined),
    ('recommending','Preparing next steps','Organizing precise improvements and transparent scores.',Icons.auto_awesome_outlined),
  ];
  static const current={
    'queued':0,'extracting':1,'parsing_job':2,'scoring':3,
    'recommending':4,'completed':5,
  };
  @override void initState(){
    super.initState();
    _refresh();
    timer=Timer.periodic(const Duration(seconds:5),(_)=>_refresh());
  }
  @override void dispose(){timer?.cancel();super.dispose();}
  String _diagnostic(String? code){
    switch(code){
      case 'cv_evidence_insufficient':
      case 'invalid_cv_json':
      case 'empty_docx':
        return 'The CV text could not be read reliably. Try a text-based PDF or DOCX.';
      case 'job_requirements_not_grounded':
      case 'invalid_job_json':
      case 'no_job_requirements':
        return 'The job requirements could not be verified. Use the complete vacancy text.';
      case 'rate_limited':
        return 'The analysis provider is currently at capacity. Please retry later.';
      case 'gemini_config_error':
      case 'gemini_not_configured':
        return 'The AI service needs configuration. Please contact an administrator.';
      case 'result_save_failed':
        return 'The report could not be saved securely. Please submit a new analysis.';
      default:
        return 'The analysis could not finish. Review your input and try again.';
    }
  }
  Future<void> _refresh()async{
    if(refreshing)return;
    refreshing=true;
    try{
      final data=await AnalysisApi.results(widget.analysisId);
      if(!mounted)return;
      setState((){payload=data;error=null;});
      final analysis=data['analysis'] as Map<String,dynamic>?;
      final status=analysis?['status'] as String?;
      if(data['ready']==true||['failed','cancelled','expired'].contains(status)){
        timer?.cancel();
      }
    }catch(_){
      if(mounted)setState(()=>error='Could not refresh the status. Check your connection.');
    }finally{refreshing=false;}
  }
  Future<void> _start()async{
    if(restarting)return;
    setState(()=>restarting=true);
    final started=await AnalysisApi.startProcessing(widget.analysisId);
    if(!mounted)return;
    setState((){
      restarting=false;
      error=started?null:'The processor did not accept this job. '
        'Check its configuration or contact an administrator.';
    });
    if(started)await _refresh();
  }
  @override Widget build(BuildContext context){
    if(payload?['ready']==true)return AnalysisReportScreen(payload:payload!);
    final analysis=payload?['analysis'] as Map<String,dynamic>?;
    final status=analysis?['status'] as String? ?? 'queued';
    final failed=['failed','expired','cancelled'].contains(status);
    final phaseIndex=current[status]??0;
    final onSurface=Theme.of(context).colorScheme.onSurface;
    return AtsPage(title:'CV analysis',actions:[
      IconButton(tooltip:'Refresh the processing status',
        onPressed:_refresh,icon:const Icon(Icons.refresh_rounded)),
    ],child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const SizedBox(height:9),
      Row(children:[
        const AtsEyebrow('YOUR ANALYSIS JOURNEY'),
        const Spacer(),
        AtsStatusChip(value:status),
      ]),
      const SizedBox(height:16),
      Text(failed?'Something interrupted the analysis':
        'Making sense of your experience.',
        style:Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight:FontWeight.w900,letterSpacing:-.7,height:1.12)),
      const SizedBox(height:11),
      Text(failed
        ?_diagnostic(analysis?['failure_code'] as String?)
        :'A careful read of your CV, followed by evidence-based job matching. '
          'Every stage reflects the latest server status.',
        style:TextStyle(fontSize:13,height:1.55,
          color:onSurface.withValues(alpha:.68))),
      const SizedBox(height:24),
      Container(width:double.infinity,padding:const EdgeInsets.all(21),
        decoration:BoxDecoration(color:AtsPalette.midnight,
          borderRadius:BorderRadius.circular(23)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:49,height:49,alignment:Alignment.center,
              decoration:BoxDecoration(
                color:Colors.white.withValues(alpha:.10),
                borderRadius:BorderRadius.circular(15)),
              child:Icon(failed?Icons.priority_high_rounded:
                phaseIndex>=3?Icons.psychology_outlined:Icons.auto_awesome_rounded,
                color:const Color(0xFF87E3DD),size:27)),
            const SizedBox(width:13),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('CURRENT STAGE',style:TextStyle(color:Color(0xFF87E3DD),
                fontWeight:FontWeight.w900,fontSize:10,letterSpacing:1.4)),
              const SizedBox(height:5),
              Text(failed?'Requires attention':phases[phaseIndex.clamp(0,4)].$2,
                style:const TextStyle(color:Colors.white,fontSize:17,
                  fontWeight:FontWeight.w800)),
            ])),
          ]),
          const SizedBox(height:18),
          if(!failed)const ClipRRect(
            borderRadius:BorderRadius.all(Radius.circular(10)),
            child:LinearProgressIndicator(
              backgroundColor:Color(0xFF334562),minHeight:5,
              color:Color(0xFF87E3DD))),
          if(failed)const Text('No report was fabricated or saved as completed.',
            style:TextStyle(color:Color(0xFFBED1E4),fontSize:12)),
          const SizedBox(height:11),
          Text(failed?'The current request has stopped.':
            'Stage ${phaseIndex+1} of ${phases.length} · No estimated completion time',
            style:const TextStyle(color:Color(0xFFB6CBE0),fontSize:11)),
        ])),
      const SizedBox(height:25),
      const AtsSectionTitle('Processing timeline',
        subtitle:'A transparent view of the steps behind your report'),
      const SizedBox(height:14),
      AtsPanel(child:Column(children:[
        for(var i=0;i<phases.length;i++)_PhaseRow(
          index:i,phase:phases[i],active:!failed&&i==phaseIndex,
          complete:!failed&&i<phaseIndex,
          last:i==phases.length-1,
        ),
      ])),
      if(error!=null)...[
        const SizedBox(height:15),
        _Notice(icon:Icons.wifi_off_outlined,message:error!,
          color:AtsPalette.danger),
      ],
      if(status=='queued')...[
        const SizedBox(height:18),
        SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:restarting?null:_start,
          icon:const Icon(Icons.play_arrow_rounded),
          label:Text(restarting?'Contacting the processor…':'Start processing'))),
      ],
      if(failed)...[
        const SizedBox(height:18),
        SizedBox(width:double.infinity,child:OutlinedButton.icon(
          onPressed:()=>Navigator.maybePop(context),
          icon:const Icon(Icons.arrow_back_rounded),
          label:const Text('Return to your workspace'))),
      ],
      const SizedBox(height:18),
      _Notice(icon:Icons.shield_outlined,color:AtsPalette.brand,
        message:'Your document remains private. The app will keep the result '
          'in your history when processing completes.'),
      const SizedBox(height:13),
      Center(child:TextButton.icon(onPressed:_refresh,
        icon:const Icon(Icons.refresh_rounded,size:17),
        label:const Text('Refresh now'))),
      const SizedBox(height:7),
      const Center(child:Text('AI insights are advisory. Never add experience you do not have.',
        textAlign:TextAlign.center,
        style:TextStyle(color:AtsPalette.muted,fontSize:11,height:1.5))),
    ]));
  }
}
class _PhaseRow extends StatelessWidget{
  const _PhaseRow({required this.index,required this.phase,
    required this.active,required this.complete,required this.last});
  final int index;final (String,String,String,IconData) phase;
  final bool active,complete,last;
  @override Widget build(BuildContext context){
    final tone=complete?AtsPalette.success:active?AtsPalette.brand:AtsPalette.muted;
    return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Column(children:[
        AnimatedContainer(duration:const Duration(milliseconds:250),
          width:40,height:40,
          decoration:BoxDecoration(
            color:tone.withValues(alpha:active?.14:.08),
            borderRadius:BorderRadius.circular(13),
            border:active?Border.all(color:tone.withValues(alpha:.5)):null),
          child:complete?const Icon(Icons.check_rounded,color:AtsPalette.success):
            Icon(phase.$4,size:21,color:tone)),
        if(!last)Container(width:2,height:34,
          color:complete?AtsPalette.success.withValues(alpha:.35):
            AtsPalette.stroke),
      ]),
      const SizedBox(width:14),
      Expanded(child:Padding(padding:const EdgeInsets.only(top:2,bottom:25),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Expanded(child:Text(phase.$2,style:TextStyle(
              fontSize:14,fontWeight:FontWeight.w800,
              color:active?tone:null))),
            if(active)const SizedBox(width:7),
            if(active)const SizedBox(width:13,height:13,
              child:CircularProgressIndicator(strokeWidth:2.1)),
          ]),
          const SizedBox(height:5),
          Text(phase.$3,style:const TextStyle(
            color:AtsPalette.muted,fontSize:12,height:1.45)),
          if(complete)...[
            const SizedBox(height:5),
            const Text('Complete',style:TextStyle(
              color:AtsPalette.success,fontWeight:FontWeight.w700,fontSize:11)),
          ],
        ]))),
    ]);
  }
}
class _Notice extends StatelessWidget{
  const _Notice({required this.icon,required this.message,required this.color});
  final IconData icon;final String message;final Color color;
  @override Widget build(BuildContext context)=>Container(
    width:double.infinity,padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(
      color:color.withValues(alpha:.07),
      borderRadius:BorderRadius.circular(13)),
    child:Row(children:[
      Icon(icon,size:19,color:color),
      const SizedBox(width:11),
      Expanded(child:Text(message,style:const TextStyle(
        color:AtsPalette.muted,fontSize:12,height:1.5))),
    ]));
}
