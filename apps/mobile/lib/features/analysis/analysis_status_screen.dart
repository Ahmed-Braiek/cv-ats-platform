import 'dart:async';

import 'package:flutter/material.dart';
import '../../ui/ats_design.dart';
import 'analysis_api.dart';

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

    final ats=Map<String,dynamic>.from(payload!['ats'] as Map);
    final match=Map<String,dynamic>.from(payload!['match'] as Map);
    final recs=(payload!['recommendations'] as List<dynamic>? ?? [])
      .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    return DefaultTabController(length:4,child:Scaffold(
      appBar:AppBar(title:const Text('Your analysis is ready')),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(18,8,18,0),
          child:Container(
            padding:const EdgeInsets.symmetric(horizontal:5,vertical:7),
            decoration:BoxDecoration(
              color:AtsPalette.success.withValues(alpha:.09),
              borderRadius:BorderRadius.circular(12)),
            child:const Row(children:[
              Icon(Icons.verified_rounded,color:AtsPalette.success),
              SizedBox(width:8),
              Expanded(child:Text('Completed • Results saved to your account',
                style:TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
            ]),
          )),
        const TabBar(isScrollable:true,tabAlignment:TabAlignment.start,
          tabs:[Tab(text:'Overview'),Tab(text:'ATS'),Tab(text:'Job Match'),
            Tab(text:'Recommendations')]),
        Expanded(child:TabBarView(children:[
          _OverviewTab(ats:ats,match:match,issues:recs.length),
          _AtsTab(result:ats),
          _MatchTab(result:match),
          _RecommendationsTab(items:recs),
        ])),
      ])),
    ));
  }
}

class _TabPage extends StatelessWidget {
  const _TabPage({required this.children});
  final List<Widget> children;
  @override Widget build(BuildContext context)=>Center(child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:760),
    child:ListView(padding:const EdgeInsets.all(20),children:children)));
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.title,required this.value,
    required this.color,required this.icon,this.subtitle});
  final String title;
  final int value;
  final Color color;
  final IconData icon;
  final String? subtitle;
  @override Widget build(BuildContext context)=>AtsPanel(child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(icon,color:color,size:23),const SizedBox(width:9),
        Expanded(child:Text(title,style:const TextStyle(
          fontWeight:FontWeight.w800,fontSize:17))),
      ]),
      const SizedBox(height:18),
      Text('$value',style:Theme.of(context).textTheme.displayMedium?.copyWith(
        fontWeight:FontWeight.w900,color:color)),
      const SizedBox(height:2),
      Text('out of 100',style:TextStyle(
        color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.6))),
      const SizedBox(height:17),
      ClipRRect(borderRadius:BorderRadius.circular(10),
        child:LinearProgressIndicator(
          value:value/100,minHeight:9,
          backgroundColor:color.withValues(alpha:.10),
          valueColor:AlwaysStoppedAnimation<Color>(color))),
      if(subtitle!=null)...[
        const SizedBox(height:12),
        Text(subtitle!,style:const TextStyle(
          color:AtsPalette.muted,fontSize:12,height:1.4)),
      ],
    ]));
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.ats,required this.match,required this.issues});
  final Map<String,dynamic> ats,match;
  final int issues;
  @override Widget build(BuildContext context)=>_TabPage(children:[
    const AtsHeader(title:'Your application insights',
      subtitle:'Two separate assessments, each answering a different question.'),
    _ScoreCard(title:'ATS compatibility',value:ats['overall'] as int,
      color:AtsPalette.brand,icon:Icons.fact_check_outlined,
      subtitle:'Measures basic parsing and structural readiness, not employer-specific ATS ranking.'),
    const SizedBox(height:12),
    _ScoreCard(title:'Job Match',value:match['overall'] as int,
      color:AtsPalette.ocean,icon:Icons.track_changes_outlined,
      subtitle:'Initial skill coverage against explicitly stated job requirements.'),
    const SizedBox(height:17),
    AtsPanel(child:Row(children:[
      const Icon(Icons.lightbulb_outline,color:AtsPalette.warn),
      const SizedBox(width:13),
      Expanded(child:Text('$issues improvement suggestions available',
        style:const TextStyle(fontWeight:FontWeight.w700))),
    ])),
    const SizedBox(height:17),
    const Text('These are experimental, explainable indicators. They do not predict recruitment outcomes.',
      style:TextStyle(color:AtsPalette.muted,fontSize:12)),
  ]);
}

class _AtsTab extends StatelessWidget{
  const _AtsTab({required this.result});
  final Map<String,dynamic> result;
  @override Widget build(BuildContext context){
    final rubric=Map<String,dynamic>.from(result['rubric_json'] as Map? ?? {});
    final parts=Map<String,dynamic>.from(rubric['components'] as Map? ?? {});
    const maxima={'contact':15,'skills_section':20,'experience_section':20,
      'education_section':15,'standard_headings':15,'selectable_text':15};
    const names={'contact':'Contact information','skills_section':'Skills section',
      'experience_section':'Experience section','education_section':'Education',
      'standard_headings':'Clear headings','selectable_text':'Text readability'};
    return _TabPage(children:[
      const AtsHeader(title:'ATS compatibility',
        subtitle:'A transparent assessment of how the document is organized.'),
      _ScoreCard(title:'ATS score',value:result['overall'] as int,
        color:AtsPalette.brand,icon:Icons.description_outlined),
      const SizedBox(height:24),
      const AtsSectionTitle('Score breakdown'),
      const SizedBox(height:13),
      for(final entry in parts.entries)Padding(
        padding:const EdgeInsets.only(bottom:11),
        child:AtsPanel(child:Row(children:[
          Expanded(child:Text(names[entry.key]??entry.key.replaceAll('_',' '),
            style:const TextStyle(fontWeight:FontWeight.w700))),
          Text('${entry.value} / ${maxima[entry.key] ?? 0}',
            style:const TextStyle(color:AtsPalette.brand,fontWeight:FontWeight.w900)),
        ]))),
      const SizedBox(height:12),
      const Text('Rubric version: ats-match-v0.1. This baseline still requires external ATS validation.',
        style:TextStyle(color:AtsPalette.muted,fontSize:12)),
    ]);
  }
}

class _MatchTab extends StatelessWidget{
  const _MatchTab({required this.result});
  final Map<String,dynamic> result;
  @override Widget build(BuildContext context){
    final rubric=Map<String,dynamic>.from(result['rubric_json'] as Map? ?? {});
    final matched=(rubric['matched_required'] as List<dynamic>? ?? []);
    final missing=(rubric['missing_required'] as List<dynamic>? ?? []);
    final preferred=(rubric['missing_preferred'] as List<dynamic>? ?? []);
    return _TabPage(children:[
      const AtsHeader(title:'Job Match',
        subtitle:'Compare evidenced CV skills with the job description.'),
      _ScoreCard(title:'Job Match score',value:result['overall'] as int,
        color:AtsPalette.ocean,icon:Icons.track_changes_outlined),
      const SizedBox(height:20),
      _MatchSection('Matched required skills',matched,AtsPalette.success,
        Icons.check_circle_outline),
      const SizedBox(height:14),
      _MatchSection('Missing required skills',missing,AtsPalette.danger,
        Icons.info_outline),
      const SizedBox(height:14),
      _MatchSection('Missing preferred skills',preferred,AtsPalette.warn,
        Icons.lightbulb_outline),
      const SizedBox(height:15),
      const Text('Missing evidence is not proof you lack a skill. Update your CV only with accurate claims.',
        style:TextStyle(color:AtsPalette.muted,fontSize:12)),
    ]);
  }
}
class _MatchSection extends StatelessWidget{
  const _MatchSection(this.title,this.items,this.color,this.icon);
  final String title;
  final List<dynamic> items;
  final Color color;
  final IconData icon;
  @override Widget build(BuildContext context)=>AtsPanel(
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(icon,color:color,size:20),const SizedBox(width:9),
        Expanded(child:Text(title,style:const TextStyle(
          fontWeight:FontWeight.w800,fontSize:15))),
        Text('${items.length}',style:TextStyle(color:color,
          fontWeight:FontWeight.w800)),
      ]),
      const SizedBox(height:13),
      if(items.isEmpty)const Text('No items identified.',
        style:TextStyle(color:AtsPalette.muted)),
      if(items.isNotEmpty)Wrap(spacing:7,runSpacing:5,children:[
        for(final item in items)Chip(
          label:Text(item.toString()),
          avatar:Icon(icon,size:16,color:color)),
      ]),
    ]),
  );
}

class _RecommendationsTab extends StatelessWidget{
  const _RecommendationsTab({required this.items});
  final List<Map<String,dynamic>> items;
  @override Widget build(BuildContext context)=>_TabPage(children:[
    const AtsHeader(title:'Recommendations',
      subtitle:'Clear next steps grounded in your document evidence.'),
    if(items.isEmpty)const AtsEmptyState(
      icon:Icons.check_circle_outline,title:'No recommendations generated',
      description:'The current evaluation did not identify any suggestions.'),
    for(final (i,item) in items.indexed)Padding(
      padding:const EdgeInsets.only(bottom:12),
      child:AtsPanel(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:35,height:35,alignment:Alignment.center,
          decoration:BoxDecoration(
            color:(i==0?AtsPalette.brand:AtsPalette.ocean).withValues(alpha:.1),
            borderRadius:BorderRadius.circular(11)),
          child:Text('${i+1}',style:const TextStyle(
            fontWeight:FontWeight.w900,color:AtsPalette.brand))),
        const SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          AtsEyebrow((item['category'] as String?)??'IMPROVEMENT'),
          const SizedBox(height:6),
          Text((item['message'] as String?)??'',
            style:const TextStyle(height:1.5,fontSize:14)),
        ])),
      ])),
    ),
    const SizedBox(height:14),
    const Text('Never add false skills, work history or qualifications to your CV.',
      style:TextStyle(color:AtsPalette.muted,fontSize:12)),
  ]);
}
