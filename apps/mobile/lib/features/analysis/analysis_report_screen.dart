import 'package:flutter/material.dart';
import '../../ui/ats_design.dart';

Map<String,dynamic> _map(dynamic x)=>x is Map?Map<String,dynamic>.from(x):{};
List<Map<String,dynamic>> _list(dynamic x)=>x is List?
    x.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
String _str(dynamic x,[String empty=''])=>x is String&&x.trim().isNotEmpty?x.trim():empty;
int _val(Map<String,dynamic> x)=>((x['overall'] is num?x['overall'] as num:0).clamp(0,100)).toInt();
Color _statusColor(String s)=>s=='direct'?AtsPalette.success:
    s=='transferable'?AtsPalette.brand:s=='missing'?AtsPalette.danger:AtsPalette.warn;
String _statusText(String s)=>s=='direct'?'EVIDENCED':s=='transferable'?'TRANSFERABLE':
    s=='missing'?'NOT DEMONSTRATED':'REVIEW NEEDED';
String _grade(int s)=>s>=75?'Strong evidence':s>=50?'Partial alignment':
    s>=25?'Developing alignment':'Limited evidence';

class AnalysisReportScreen extends StatelessWidget{
  const AnalysisReportScreen({super.key,required this.payload});
  final Map<String,dynamic> payload;
  @override Widget build(BuildContext context){
    final ats=_map(payload['ats']),match=_map(payload['match']);
    final ar=_map(ats['rubric_json']),mr=_map(match['rubric_json']);
    final actions=_list(payload['recommendations']);
    final modern=mr['version']=='ats-match-v0.2';
    return DefaultTabController(length:4,child:Scaffold(
      appBar:AppBar(title:const Text('Your CV report'),actions:[
        Padding(padding:const EdgeInsets.only(right:15),child:Center(
          child:_Pill('COMPLETE',AtsPalette.success))),
      ]),
      body:SafeArea(child:Column(children:[
        const TabBar(isScrollable:true,tabAlignment:TabAlignment.start,
          dividerHeight:0,tabs:[
            Tab(text:'Overview'),Tab(text:'CV readiness'),
            Tab(text:'Job match'),Tab(text:'Next steps'),
          ]),
        Expanded(child:TabBarView(children:[
          _Scroll(children:[
            if(!modern)const _LegacyBanner(),
            _Hero(score:_val(match),rubric:mr,modern:modern),
            const SizedBox(height:21),
            const AtsEyebrow('AT A GLANCE'),
            const SizedBox(height:10),
            Row(children:[
              Expanded(child:_ScoreTile(value:_val(ats),title:'Document readiness',
                color:AtsPalette.brand,icon:Icons.article_outlined)),
              const SizedBox(width:10),
              Expanded(child:_ScoreTile(value:_val(match),title:'Job alignment',
                color:AtsPalette.ocean,icon:Icons.track_changes_outlined)),
            ]),
            const SizedBox(height:21),
            AtsSectionTitle('What the CV demonstrates',
              subtitle:modern?'Grounded in the job requirements and extracted CV evidence':
                'This older analysis only checked exact keywords'),
            const SizedBox(height:12),
            if(modern)_Counts(rubric:mr)else const _OldHint(),
            const SizedBox(height:22),
            if(modern)_Highlights(rubric:mr),
            const SizedBox(height:15),
            const _Disclaimer(),
          ]),
          _Scroll(children:[
            if(!modern)const _LegacyBanner(),
            const AtsEyebrow('DOCUMENT QUALITY'),
            const SizedBox(height:7),
            const AtsHeader(title:'A readable, structured CV.',
              subtitle:'Document readiness is different from job fit. '
                'A well-formatted CV can still miss important role requirements.'),
            _ScoreTile(value:_val(ats),title:'Document readiness',
              color:AtsPalette.brand,icon:Icons.fact_check_outlined),
            const SizedBox(height:22),
            AtsSectionTitle('Scoring checks',subtitle:modern?
              'Transparent points and reasoning for each check':
              'Earlier simplified rubric'),
            const SizedBox(height:13),
            _AtsChecks(rubric:ar,modern:modern),
            const SizedBox(height:16),
            const _Disclaimer(),
          ]),
          _MatchTab(rubric:mr,score:_val(match),modern:modern),
          _Scroll(children:[
            if(!modern)const _LegacyBanner(),
            const AtsEyebrow('YOUR NEXT MOVE'),
            const SizedBox(height:7),
            const AtsHeader(title:'A more focused next draft.',
              subtitle:'Start with missing required evidence. Show relevant '
                'transferable experience without inventing qualifications.'),
            Container(
              padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(color:AtsPalette.midnight,
                borderRadius:BorderRadius.circular(20)),
              child:Row(children:[
                const Icon(Icons.edit_note_outlined,size:36,color:Color(0xFF8BE7E1)),
                const SizedBox(width:14),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${actions.length} actionable suggestions',
                    style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:17)),
                  const SizedBox(height:6),
                  const Text('Prioritized, grounded and honest.',
                    style:TextStyle(color:Color(0xFFB2C4D9),fontSize:12)),
                ])),
              ]),
            ),
            const SizedBox(height:18),
            for(var i=0;i<actions.length;i++)
              Padding(padding:const EdgeInsets.only(bottom:12),
                child:_ActionTile(index:i+1,item:actions[i])),
            if(actions.isEmpty)const AtsEmptyState(
              icon:Icons.fact_check_outlined,title:'No suggestions found',
              description:'Check the readiness and job match tabs for more detail.'),
            const SizedBox(height:16),
            const _Disclaimer(),
          ]),
        ])),
      ])),
    ));
  }
}

class _Scroll extends StatelessWidget{
  const _Scroll({required this.children});
  final List<Widget> children;
  @override Widget build(BuildContext context)=>Center(child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:760),
    child:ListView(padding:const EdgeInsets.fromLTRB(18,21,18,34),
      children:children)));
}
class _Pill extends StatelessWidget{
  const _Pill(this.label,this.color);
  final String label;final Color color;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
    decoration:BoxDecoration(color:color.withValues(alpha:.1),
      borderRadius:BorderRadius.circular(30)),
    child:Text(label,style:TextStyle(color:color,fontWeight:FontWeight.w900,
      fontSize:10,letterSpacing:.35)),
  );
}
class _Hero extends StatelessWidget{
  const _Hero({required this.score,required this.rubric,required this.modern});
  final int score;final Map<String,dynamic> rubric;final bool modern;
  @override Widget build(BuildContext context){
    final summary=_map(rubric['summary']);
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(21),
      decoration:BoxDecoration(color:AtsPalette.midnight,
        borderRadius:BorderRadius.circular(24)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const AtsEyebrow('ROLE ALIGNMENT',color:Color(0xFF81E3DE)),
        const SizedBox(height:9),
        Text(_str(rubric['job_title'],'Your target role'),
          style:const TextStyle(color:Colors.white,fontSize:22,
            fontWeight:FontWeight.w900,height:1.2)),
        const SizedBox(height:20),
        Row(children:[
          SizedBox(width:102,height:102,child:Stack(
            alignment:Alignment.center,children:[
              SizedBox(width:95,height:95,child:CircularProgressIndicator(
                value:score/100,strokeWidth:9,strokeCap:StrokeCap.round,
                backgroundColor:const Color(0xFF344666),
                valueColor:const AlwaysStoppedAnimation<Color>(Color(0xFF88DFE0)))),
              Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text('$score',style:const TextStyle(color:Colors.white,
                  fontSize:31,fontWeight:FontWeight.w900,height:1)),
                const Text('out of 100',style:TextStyle(
                  color:Color(0xFFC0CFDD),fontSize:10)),
              ]),
            ])),
          const SizedBox(width:17),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_grade(score),style:const TextStyle(color:Colors.white,
              fontSize:18,fontWeight:FontWeight.w900,height:1.2)),
            const SizedBox(height:8),
            Text(modern?'${summary['total']??0} job criteria checked':
              'Legacy keyword comparison',style:const TextStyle(
                color:Color(0xFFB9CEE0),fontSize:12)),
            const SizedBox(height:9),
            const Text('Not an interview probability or employer ATS rating.',
              style:TextStyle(color:Color(0xFFB9CEE0),fontSize:11,height:1.4)),
          ])),
        ]),
        if(modern)...[
          const SizedBox(height:20),
          Wrap(spacing:7,runSpacing:7,children:[
            _HeroCount(summary['direct'],'Evidenced'),
            _HeroCount(summary['transferable'],'Transferable'),
            _HeroCount(summary['missing'],'Gaps to review'),
          ]),
        ],
      ]),
    );
  }
}
class _HeroCount extends StatelessWidget{
  const _HeroCount(this.number,this.label);
  final dynamic number;final String label;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
    decoration:BoxDecoration(color:const Color(0xFF263957),
      borderRadius:BorderRadius.circular(10)),
    child:Text('${number??0} $label',style:const TextStyle(
      fontSize:11,color:Colors.white,fontWeight:FontWeight.w700)));
}
class _ScoreTile extends StatelessWidget{
  const _ScoreTile({required this.value,required this.title,required this.color,
    required this.icon});
  final int value;final String title;final Color color;final IconData icon;
  @override Widget build(BuildContext context)=>AtsPanel(
    padding:const EdgeInsets.all(15),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:color,size:23),
      const SizedBox(height:10),
      Text('$value/100',style:Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight:FontWeight.w900)),
      const SizedBox(height:6),
      Text(title,style:const TextStyle(color:AtsPalette.muted,fontSize:11)),
      const SizedBox(height:10),
      ClipRRect(borderRadius:BorderRadius.circular(9),
        child:LinearProgressIndicator(value:value/100,minHeight:5,
          backgroundColor:color.withValues(alpha:.12),
          valueColor:AlwaysStoppedAnimation<Color>(color))),
    ]));
}
class _Counts extends StatelessWidget{
  const _Counts({required this.rubric});
  final Map<String,dynamic> rubric;
  @override Widget build(BuildContext context){
    final s=_map(rubric['summary']);
    return AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Requirements at a glance',
        style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
      const SizedBox(height:15),
      Row(children:[
        _Count(s['direct'],'Evidenced',AtsPalette.success),
        _Count(s['transferable'],'Related',AtsPalette.brand),
        _Count(s['missing'],'Gaps',AtsPalette.warn),
      ]),
      const SizedBox(height:17),
      _Percent(label:'Required qualifications',ratio:rubric['required_coverage']),
      const SizedBox(height:12),
      _Percent(label:'Preferred qualifications',ratio:rubric['preferred_coverage']),
      const SizedBox(height:10),
      Text('Evidence review: ${_str(s['confidence'],'unverified').replaceAll('_',' ')}',
        style:const TextStyle(fontSize:11,color:AtsPalette.muted)),
    ]));
  }
}
class _Count extends StatelessWidget{
  const _Count(this.value,this.label,this.color);
  final dynamic value;final String label;final Color color;
  @override Widget build(BuildContext context)=>Expanded(child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${value??0}',style:TextStyle(
        fontSize:25,fontWeight:FontWeight.w900,color:color)),
      Text(label,style:const TextStyle(color:AtsPalette.muted,fontSize:11)),
    ]));
}
class _Percent extends StatelessWidget{
  const _Percent({required this.label,required this.ratio});
  final String label;final dynamic ratio;
  @override Widget build(BuildContext context){
    final double? amount=ratio is num ? ratio.toDouble().clamp(0.0,1.0).toDouble() : null;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(label,style:const TextStyle(
          fontWeight:FontWeight.w700,fontSize:12))),
        Text(amount==null?'Not assessed':'${(amount*100).round()}%',
          style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
      ]),
      const SizedBox(height:8),
      ClipRRect(borderRadius:BorderRadius.circular(8),
        child:LinearProgressIndicator(value:amount??0,minHeight:6,
          backgroundColor:AtsPalette.brand.withValues(alpha:.1),
          valueColor:const AlwaysStoppedAnimation<Color>(AtsPalette.brand))),
    ]);
  }
}
class _Highlights extends StatelessWidget{
  const _Highlights({required this.rubric});
  final Map<String,dynamic> rubric;
  @override Widget build(BuildContext context){
    final criteria=_list(rubric['requirements']);
    final demonstrated=criteria.where((x)=>x['status']=='direct').take(2);
    final related=criteria.where((x)=>x['status']=='transferable').take(2);
    final gaps=criteria.where((x)=>(x['status']=='missing'||x['status']=='uncertain')&&
      x['importance']=='required').take(3);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(demonstrated.isNotEmpty)...[
        const AtsSectionTitle('Proven strengths'),
        const SizedBox(height:10),
        for(final r in demonstrated)_Mini(r,AtsPalette.success),
        const SizedBox(height:17),
      ],
      if(related.isNotEmpty)...[
        const AtsSectionTitle('Transferable strengths',
          subtitle:'Relevant but not identical experience'),
        const SizedBox(height:10),
        for(final r in related)_Mini(r,AtsPalette.brand),
        const SizedBox(height:17),
      ],
      if(gaps.isNotEmpty)...[
        const AtsSectionTitle('High-impact gaps'),
        const SizedBox(height:10),
        for(final r in gaps)_Mini(r,AtsPalette.warn),
      ],
    ]);
  }
}
class _Mini extends StatelessWidget{
  const _Mini(this.r,this.tone);
  final Map<String,dynamic> r;final Color tone;
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.only(bottom:9),
    child:AtsPanel(padding:const EdgeInsets.all(14),
      child:Row(children:[
        Icon(Icons.circle,size:9,color:tone),
        const SizedBox(width:10),
        Expanded(child:Text(_str(r['text'],'Requirement'),
          style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,height:1.45))),
      ])));
}
class _AtsChecks extends StatelessWidget{
  const _AtsChecks({required this.rubric,required this.modern});
  final Map<String,dynamic> rubric;final bool modern;
  @override Widget build(BuildContext context){
    final checks=_list(rubric['checks']);
    if(checks.isEmpty){
      const limits={'contact':15,'skills_section':20,'experience_section':20,
        'education_section':15,'standard_headings':15,'selectable_text':15};
      final old=_map(rubric['components']);
      return Column(children:[
        for(final x in old.entries)Padding(padding:const EdgeInsets.only(bottom:11),
          child:_Check(title:x.key.replaceAll('_',' '),
            value:x.value is num?(x.value as num).toInt():0,
            max:limits[x.key]??15,
            note:'Legacy check. Detail was not stored in this analysis.')),
      ]);
    }
    return Column(children:[
      for(final x in checks)Padding(padding:const EdgeInsets.only(bottom:11),
        child:_Check(title:_str(x['title'],'Readiness check'),
          value:x['score'] is num?(x['score'] as num).toInt():0,
          max:x['max'] is num?(x['max'] as num).toInt():10,
          note:_str(x['note']))),
    ]);
  }
}
class _Check extends StatelessWidget{
  const _Check({required this.title,required this.value,
    required this.max,required this.note});
  final String title,note;final int value,max;
  @override Widget build(BuildContext context){
    final double pct=max>0?(value/max).clamp(0.0,1.0).toDouble():0.0;
    final tone=pct>=.85?AtsPalette.success:
      pct>=.5?AtsPalette.brand:AtsPalette.warn;
    return AtsPanel(padding:const EdgeInsets.all(16),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text(title,style:const TextStyle(
            fontWeight:FontWeight.w800,fontSize:14))),
          Text('$value/$max',style:TextStyle(color:tone,
            fontWeight:FontWeight.w900)),
        ]),
        const SizedBox(height:10),
        ClipRRect(borderRadius:BorderRadius.circular(10),
          child:LinearProgressIndicator(value:pct,minHeight:7,
            backgroundColor:tone.withValues(alpha:.1),
            valueColor:AlwaysStoppedAnimation<Color>(tone))),
        if(note.isNotEmpty)...[
          const SizedBox(height:10),
          Text(note,style:const TextStyle(
            color:AtsPalette.muted,fontSize:12,height:1.5)),
        ],
      ]));
  }
}
class _MatchTab extends StatefulWidget{
  const _MatchTab({required this.rubric,required this.score,required this.modern});
  final Map<String,dynamic> rubric;final int score;final bool modern;
  @override State<_MatchTab> createState()=>_MatchTabState();
}
class _MatchTabState extends State<_MatchTab>{
  String filter='All';
  @override Widget build(BuildContext context){
    if(!widget.modern)return _Scroll(children:[
      const _LegacyBanner(),const AtsHeader(title:'Keyword results',
        subtitle:'A new analysis is required for evidence-linked breakdowns.'),
      for(final key in ['matched_required','missing_required','missing_preferred'])
        AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(key.replaceAll('_',' '),style:const TextStyle(fontWeight:FontWeight.w800)),
          ...((widget.rubric[key] as List?)??[]).map((x)=>Padding(
            padding:const EdgeInsets.only(top:7),child:Text('• $x'))),
        ])),
    ]);
    final criteria=_list(widget.rubric['requirements']);
    final shown=criteria.where((r){
      final s=_str(r['status']);
      if(filter=='All')return true;
      if(filter=='Evidenced')return s=='direct';
      if(filter=='Related')return s=='transferable';
      if(filter=='Gaps')return s=='missing'||s=='uncertain';
      return r['importance']=='preferred';
    });
    final breakdown=_map(widget.rubric['category_scores']);
    const labels={'hard_skill':'Technical skills','tool':'Tools & platforms',
      'experience':'Role experience','education':'Education',
      'responsibility':'Responsibilities','soft_skill':'Communication & teamwork'};
    return _Scroll(children:[
      const AtsEyebrow('THE EVIDENCE'),
      const SizedBox(height:7),
      AtsHeader(title:_str(widget.rubric['job_title'],'Job match'),
        subtitle:'Match decisions are backed by excerpts from the CV, '
          'or marked as unsupported. Tap the filters to explore.'),
      _ScoreTile(value:widget.score,title:_grade(widget.score),
        color:AtsPalette.ocean,icon:Icons.track_changes_outlined),
      const SizedBox(height:20),
      const AtsSectionTitle('Alignment by area'),
      const SizedBox(height:11),
      AtsPanel(child:Column(children:[
        for(final x in breakdown.entries)
          if(x.value is num)...[
            _Percent(label:labels[x.key]??x.key,
              ratio:(x.value as num)/100),
            const SizedBox(height:12),
          ],
      ])),
      const SizedBox(height:22),
      AtsSectionTitle('Requirement-by-requirement',
        subtitle:'${criteria.length} criteria from the job description'),
      const SizedBox(height:12),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(final value in ['All','Evidenced','Related','Gaps','Preferred'])
          Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(
            label:Text(value),selected:filter==value,
            onSelected:(_)=>setState(()=>filter=value))),
      ])),
      const SizedBox(height:15),
      for(final r in shown)Padding(padding:const EdgeInsets.only(bottom:12),
        child:_Requirement(r)),
      if(shown.isEmpty)const AtsEmptyState(icon:Icons.filter_alt_off_outlined,
        title:'Nothing in this category',
        description:'Choose another filter to review more criteria.'),
      const SizedBox(height:16),
      const _Disclaimer(),
    ]);
  }
}
class _Requirement extends StatelessWidget{
  const _Requirement(this.item);
  final Map<String,dynamic> item;
  @override Widget build(BuildContext context){
    final s=_str(item['status'],'uncertain'),tone=_statusColor(s);
    final proof=_str(item['evidence_quote']),source=_str(item['source_quote']);
    return AtsPanel(padding:const EdgeInsets.all(17),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(spacing:7,runSpacing:7,children:[
          _Pill(_statusText(s),tone),
          _Pill(item['importance']=='preferred'?'PREFERRED':'REQUIRED',AtsPalette.muted),
        ]),
        const SizedBox(height:12),
        Text(_str(item['text'],'Requirement'),
          style:Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight:FontWeight.w800,height:1.35)),
        const SizedBox(height:8),
        Text(_str(item['explanation'],'No evidence identified'),
          style:const TextStyle(color:AtsPalette.muted,fontSize:12,height:1.5)),
        if(proof.isNotEmpty)...[
          const SizedBox(height:13),
          const AtsEyebrow('EVIDENCE IN YOUR CV'),
          const SizedBox(height:8),
          Container(width:double.infinity,padding:const EdgeInsets.all(13),
            decoration:BoxDecoration(
              color:tone.withValues(alpha:.08),borderRadius:BorderRadius.circular(11),
              border:Border(left:BorderSide(color:tone,width:3))),
            child:Text('“$proof”',style:const TextStyle(
              fontSize:12,fontWeight:FontWeight.w600,height:1.55))),
        ]else ...[
          const SizedBox(height:12),
          const Text('No verifiable passage found in this CV.',
            style:TextStyle(fontSize:12,color:AtsPalette.muted)),
        ],
        if(source.isNotEmpty)...[
          const SizedBox(height:12),
          Text('JOB REQUIREMENT: $source',style:TextStyle(fontSize:11,
            height:1.5,color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.56))),
        ],
      ]));
  }
}
class _ActionTile extends StatelessWidget{
  const _ActionTile({required this.index,required this.item});
  final int index;final Map<String,dynamic> item;
  @override Widget build(BuildContext context){
    final priority=item['priority'] is num?(item['priority'] as num).toInt():3;
    final tone=priority==1?AtsPalette.danger:priority==2?
      AtsPalette.brand:AtsPalette.success;
    return AtsPanel(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:36,height:36,alignment:Alignment.center,
        decoration:BoxDecoration(
          color:tone.withValues(alpha:.11),borderRadius:BorderRadius.circular(10)),
        child:Text('$index',style:TextStyle(color:tone,fontWeight:FontWeight.w900))),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:AtsEyebrow(
            _str(item['category'],'Improvement').replaceAll('_',' '),color:tone)),
          Text(priority==1?'IMPORTANT':priority==2?'CONSIDER':'POLISH',
            style:TextStyle(color:tone,fontSize:9,fontWeight:FontWeight.w800)),
        ]),
        const SizedBox(height:8),
        Text(_str(item['message'],'Review your CV.'),
          style:const TextStyle(height:1.55,fontWeight:FontWeight.w600)),
      ])),
    ]));
  }
}
class _OldHint extends StatelessWidget{
  const _OldHint();
  @override Widget build(BuildContext context)=>const AtsEmptyState(
    icon:Icons.history_outlined,title:'Reanalyze to upgrade',
    description:'Old scores cannot be reliably converted to evidence-based scores. '
      'Submit a new analysis to view direct, transferable and missing evidence.');
}
class _LegacyBanner extends StatelessWidget{
  const _LegacyBanner();
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.only(bottom:16),
    child:Container(padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(
        color:AtsPalette.warn.withValues(alpha:.1),
        borderRadius:BorderRadius.circular(12)),
      child:const Row(children:[
        Icon(Icons.history_edu_outlined,color:AtsPalette.warn),
        SizedBox(width:11),
        Expanded(child:Text('This older result used keyword-only scoring. '
          'Create a new analysis for v0.2 evidence and recommendations.',
          style:TextStyle(fontSize:12,height:1.5))),
      ])));
}
class _Disclaimer extends StatelessWidget{
  const _Disclaimer();
  @override Widget build(BuildContext context)=>const Text(
    'Informational assessment, not an official applicant tracking system '
    'or a prediction of hiring outcomes. Never invent credentials or experience.',
    style:TextStyle(color:AtsPalette.muted,fontSize:11,height:1.5),
    textAlign:TextAlign.center);
}
