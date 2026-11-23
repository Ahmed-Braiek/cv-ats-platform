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
    if(!ready)return AtsPage(title:'CV analysis',actions:[
      IconButton(tooltip:'Refresh status',
        onPressed:_refresh,icon:const Icon(Icons.refresh_rounded)),
    ],child:Column(children:[
      const SizedBox(height:23),
      Container(padding:const EdgeInsets.all(21),
        decoration:BoxDecoration(
          color:AtsPalette.brand.withValues(alpha:.09),
          shape:BoxShape.circle),
        child:Icon(['failed','cancelled','expired'].contains(status)
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
        Text(error ?? (['failed','cancelled','expired'].contains(status)
          ?'The server could not complete this analysis. Please review your file and try later.'
          :'This screen refreshes automatically while processing.'),
          style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
      ])),
      const SizedBox(height:18),
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
