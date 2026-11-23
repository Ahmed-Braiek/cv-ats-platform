import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/supabase_config.dart';
import '../../ui/ats_design.dart';
import 'admin_api.dart';
import 'admin_user_sheet.dart';

String _text(dynamic x,[String alt='—']) =>
    x == null || x.toString().trim().isEmpty ? alt : x.toString();
String _date(dynamic x) {
  final d=DateTime.tryParse(_text(x,''))?.toLocal();
  if(d==null)return 'Date unavailable';
  return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
String _number(dynamic x) => x is num ? x.toStringAsFixed(x%1==0?0:1) : '—';
Color _stateColor(String s)=>s=='completed'||s=='active'?AtsPalette.success:
  s=='failed'||s=='cancelled'||s=='suspended'?AtsPalette.danger:AtsPalette.brand;

class AdminConsoleScreen extends StatefulWidget{
  const AdminConsoleScreen({super.key});
  @override State<AdminConsoleScreen> createState()=>_AdminConsoleScreenState();
}
class _AdminConsoleScreenState extends State<AdminConsoleScreen>{
  static const labels=['Overview','People','Analyses','Plans','Audit'];
  static const icons=[
    Icons.space_dashboard_outlined,Icons.people_outline_rounded,
    Icons.query_stats_rounded,Icons.workspace_premium_outlined,
    Icons.receipt_long_outlined,
  ];
  int selected=0,offset=0,limit=20;
  String statusFilter='';
  final search=TextEditingController();
  Future<dynamic>? request;
  @override void initState(){super.initState();_load();}
  @override void dispose(){search.dispose();super.dispose();}
  void _load(){
    final action=['overview','users','analyses','plans','audit'][selected];
    request=AdminApi.call(action,{
      if(action=='users')'search':search.text.trim(),
      if(action=='analyses')'status':statusFilter,
      if(['users','analyses','audit'].contains(action))...{'offset':offset,'limit':limit},
    });
  }
  void _reload(){setState(_load);}
  void _navigate(int index){
    if(selected==index)return;
    setState(() {selected=index;offset=0;_load();});
  }
  Future<void> _openUser(Map<String,dynamic> user) async {
    final changed=await showModalBottomSheet<bool>(
      context:context,isScrollControlled:true,showDragHandle:true,
      useSafeArea:true,
      builder:(_)=>AdminUserSheet(user:user),
    );
    if(changed==true&&mounted)_reload();
  }
  void _snack(String value,{bool error=false}){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(value),backgroundColor:error?AtsPalette.danger:null));
  }
  Future<void> _cancelAnalysis(Map<String,dynamic> analysis) async{
    final reason=TextEditingController();
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Cancel processing?'),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Only queued or active analyses can be cancelled. '
          'The current job will not be saved as completed.'),
        const SizedBox(height:14),
        TextField(controller:reason,maxLength:500,decoration:const InputDecoration(
          labelText:'Reason for cancellation',hintText:'e.g. Invalid input document')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Keep analysis')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Cancel analysis')),
      ],
    ));
    if(confirmed!=true||!mounted){reason.dispose();return;}
    try{
      await AdminApi.call('cancel_analysis',{
        'analysisId':analysis['id'],'reason':reason.text.trim(),
      });
      _snack('Analysis cancelled and recorded in the audit trail.');_reload();
    }catch(e){_snack('$e',error:true);}
    reason.dispose();
  }
  Future<void> _editPlan(Map<String,dynamic> plan) async{
    final code=_text(plan['code']);
    final monthly=TextEditingController(text:_text(plan['monthly_analysis_limit'],'3'));
    final saved=TextEditingController(text:_text(plan['saved_cv_limit'],'1'));
    final history=TextEditingController(text:plan['history_days']==null?'':_text(plan['history_days']));
    final reason=TextEditingController();
    var pdf=plan['pdf_export_enabled']==true;
    var busy=false;
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,update)=>AlertDialog(
        title:Text('Edit ${_text(plan['name'])} limits'),
        content:SizedBox(width:390,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
          const Text('These are plan entitlements, not billing prices.',
            style:TextStyle(color:AtsPalette.muted,fontSize:12)),
          const SizedBox(height:16),
          TextField(controller:monthly,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Analyses per month')),
          const SizedBox(height:12),
          TextField(controller:saved,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Saved CV limit')),
          const SizedBox(height:12),
          TextField(controller:history,keyboardType:TextInputType.number,
            decoration:const InputDecoration(
              labelText:'History retention (days)',hintText:'Empty = unrestricted')),
          const SizedBox(height:8),
          SwitchListTile(title:const Text('PDF export entitlement'),
            value:pdf,onChanged:busy?null:(value)=>update(()=>pdf=value)),
          const SizedBox(height:12),
          TextField(controller:reason,maxLength:500,maxLines:2,
            decoration:const InputDecoration(labelText:'Reason for this change')),
        ]))),
        actions:[
          TextButton(onPressed:busy?null:()=>Navigator.pop(ctx),
            child:const Text('Cancel')),
          FilledButton(onPressed:busy?null:() async{
            final m=int.tryParse(monthly.text.trim()),s=int.tryParse(saved.text.trim());
            final h=history.text.trim().isEmpty?null:int.tryParse(history.text.trim());
            if(m==null||s==null||m<1||s<1||
              (history.text.trim().isNotEmpty&&h==null)||reason.text.trim().length<8){
              _snack('Add valid limits and a reason of at least 8 characters.',error:true);
              return;
            }
            update(()=>busy=true);
            try{
              await AdminApi.call('update_plan',{
                'plan':code,'monthly':m,'saved':s,'history':h,
                'pdf':pdf,'reason':reason.text.trim(),
              });
              if(ctx.mounted)Navigator.pop(ctx);
              _snack('Plan limits updated and audited.');_reload();
            }catch(e){_snack('$e',error:true);if(ctx.mounted)update(()=>busy=false);}
          },child:Text(busy?'Saving…':'Save changes')),
        ],
      ),
    ));
    monthly.dispose();saved.dispose();history.dispose();reason.dispose();
  }
  @override Widget build(BuildContext context){
    return LayoutBuilder(builder:(context,box){
      final desktop=box.maxWidth>=850;
      final nav=List.generate(labels.length,(i)=>NavigationDestination(
        icon:Icon(icons[i]),selectedIcon:Icon(icons[i]),label:labels[i]));
      return Scaffold(
        appBar:AppBar(
          title:Row(children:[
            Container(padding:const EdgeInsets.all(7),
              decoration:BoxDecoration(color:AtsPalette.midnight,
                borderRadius:BorderRadius.circular(11)),
              child:const Icon(Icons.grid_view_rounded,color:Colors.white,size:21)),
            const SizedBox(width:10),
            const Flexible(child:Text('Control room',overflow:TextOverflow.ellipsis)),
          ]),
          actions:[
            PopupMenuButton<ThemeMode>(
              tooltip:'Appearance',
              icon:const Icon(Icons.palette_outlined),
              onSelected:(mode)=>AtsAppearance.mode.value=mode,
              itemBuilder:(_)=>const [
                PopupMenuItem(value:ThemeMode.system,child:Text('Device theme')),
                PopupMenuItem(value:ThemeMode.light,child:Text('Light theme')),
                PopupMenuItem(value:ThemeMode.dark,child:Text('Dark theme')),
              ]),
            IconButton(icon:const Icon(Icons.refresh_rounded),tooltip:'Refresh data',
              onPressed:_reload),
            IconButton(icon:const Icon(Icons.logout_rounded),tooltip:'Sign out',
              onPressed:() async=>SupabaseConfig.client.auth.signOut()),
          ],
        ),
        body:SafeArea(child:Row(children:[
          if(desktop)NavigationRail(
            selectedIndex:selected,extended:box.maxWidth>=1200,
            labelType:box.maxWidth>=1200?NavigationRailLabelType.none:
              NavigationRailLabelType.all,
            leading:const Padding(padding:EdgeInsets.symmetric(vertical:16),
              child:CircleAvatar(
                backgroundColor:AtsPalette.midnight,
                child:Icon(Icons.admin_panel_settings_outlined,color:Colors.white))),
            onDestinationSelected:_navigate,
            destinations:List.generate(labels.length,(i)=>NavigationRailDestination(
              icon:Icon(icons[i]),label:Text(labels[i]))),
          ),
          Expanded(child:Center(child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:1000),
            child:FutureBuilder<dynamic>(future:request,builder:(context,s){
              if(s.connectionState!=ConnectionState.done)return const _Busy();
              if(s.hasError)return _Unavailable(message:s.error.toString(),retry:_reload);
              final data=s.data;
              return RefreshIndicator(onRefresh:() async{
                _reload();
                try{await request;}catch(_){/* shown in FutureBuilder */}
              },child:ListView(
                physics:const AlwaysScrollableScrollPhysics(),
                padding:const EdgeInsets.fromLTRB(19,20,19,34),
                children:[
                  _Heading(title:labels[selected],index:selected),
                  const SizedBox(height:22),
                  if(selected==0)_overview(AdminApi.object(data)),
                  if(selected==1)_users(AdminApi.object(data)),
                  if(selected==2)_analyses(AdminApi.object(data)),
                  if(selected==3)_plans(AdminApi.rows(data)),
                  if(selected==4)_audit(AdminApi.object(data)),
                ],
              ));
            }),
          ))),
        ])),
        bottomNavigationBar:desktop?null:NavigationBar(
          selectedIndex:selected,onDestinationSelected:_navigate,
          labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,
          destinations:nav,
        ),
      );
    });
  }

  Widget _overview(Map<String,dynamic> stats){
    final total=stats['analyses'] is num?(stats['analyses'] as num).toInt():0;
    final completed=stats['completed'] is num?(stats['completed'] as num).toInt():0;
    final rate=total==0?0:(completed*100/total).round();
    final trend=AdminApi.rows(stats['trend']);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:double.infinity,padding:const EdgeInsets.all(23),
        decoration:BoxDecoration(
          color:AtsPalette.midnight,borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const AtsEyebrow('LIVE PLATFORM OVERVIEW',color:Color(0xFF89DED6)),
          const SizedBox(height:9),
          const Text('Every application,\na clearer picture.',
            style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,
              fontSize:27,height:1.16)),
          const SizedBox(height:10),
          Text('$rate% of recorded analyses completed successfully',
            style:const TextStyle(color:Color(0xFFB9CBE3),fontSize:13)),
          const SizedBox(height:17),
          LinearProgressIndicator(value:rate/100,minHeight:7,
            borderRadius:BorderRadius.circular(12),
            backgroundColor:const Color(0xFF344A67),
            valueColor:const AlwaysStoppedAnimation(Color(0xFF82DCD6))),
        ])),
      const SizedBox(height:18),
      LayoutBuilder(builder:(ctx,c){
        final narrow=c.maxWidth<525;
        final cards=[
          _Metric('Accounts',_number(stats['users']),Icons.people_outline_rounded,AtsPalette.brand),
          _Metric('Verified',_number(stats['verified_users']),Icons.verified_user_outlined,AtsPalette.success),
          _Metric('CVs stored',_number(stats['stored_cvs']),Icons.description_outlined,AtsPalette.ocean),
          _Metric('Analyses',_number(stats['analyses']),Icons.query_stats_rounded,AtsPalette.warn),
        ];
        return GridView.count(
          crossAxisCount:narrow?2:4,crossAxisSpacing:10,mainAxisSpacing:10,
          childAspectRatio:narrow?1.12:1.05,shrinkWrap:true,
          physics:const NeverScrollableScrollPhysics(),children:cards);
      }),
      const SizedBox(height:24),
      const AtsSectionTitle('Platform health',subtitle:'Latest aggregate outcomes across all analyses'),
      const SizedBox(height:12),
      AtsPanel(child:Column(children:[
        _Pair('Completed',_number(stats['completed']),AtsPalette.success),
        const Divider(height:22),
        _Pair('Still processing',_number(stats['processing']),AtsPalette.brand),
        const Divider(height:22),
        _Pair('Failed',_number(stats['failed']),AtsPalette.danger),
        const Divider(height:22),
        _Pair('Average CV readiness',_number(stats['average_ats']),AtsPalette.ocean),
        const Divider(height:22),
        _Pair('Average job alignment',_number(stats['average_match']),AtsPalette.warn),
      ])),
      const SizedBox(height:23),
      const AtsSectionTitle('14-day activity',subtitle:'Actual analyses created per day'),
      const SizedBox(height:12),
      AtsPanel(child:trend.isEmpty
        ?const Text('No analyses during the last 14 days.',
          style:TextStyle(color:AtsPalette.muted))
        :SizedBox(height:172,child:Row(
          crossAxisAlignment:CrossAxisAlignment.end,
          children:trend.map((x){
            final maximum=trend.map((e)=>(e['total'] as num?)?.toDouble()??0)
              .fold<double>(1,(a,b)=>a>b?a:b);
            final count=(x['total'] as num?)?.toDouble()??0;
            return Expanded(child:Tooltip(
              message:'${_text(x['day'])}: ${count.toInt()} analyses',
              child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
                Text('${count.toInt()}',style:const TextStyle(
                  color:AtsPalette.muted,fontSize:10)),
                const SizedBox(height:5),
                Container(height:126*count/maximum+4,
                  margin:const EdgeInsets.symmetric(horizontal:3),
                  decoration:BoxDecoration(color:AtsPalette.brand,
                    borderRadius:BorderRadius.circular(6))),
                const SizedBox(height:7),
                Text(_text(x['day']).substring(5),style:const TextStyle(
                  fontSize:9,color:AtsPalette.muted)),
              ]),
            ));
          }).toList(),
        ))),
      const SizedBox(height:23),
      const AtsSectionTitle('Subscriptions',subtitle:'Current active memberships'),
      const SizedBox(height:12),
      AtsPanel(child:Column(children:[
        for(final sub in AdminApi.rows(stats['subscriptions']))Padding(
          padding:const EdgeInsets.only(bottom:10),
          child:_Pair(_text(sub['code']).toUpperCase(),
            _number(sub['count']),AtsPalette.brand)),
        if(AdminApi.rows(stats['subscriptions']).isEmpty)
          const Text('No active subscriptions.',style:TextStyle(color:AtsPalette.muted)),
      ])),
      const SizedBox(height:18),
      const _Footnote('Statistics show recorded platform activity. '
        'The averages do not represent actual hiring outcomes.'),
    ]);
  }

  Widget _users(Map<String,dynamic> data){
    final people=AdminApi.rows(data['items']);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextField(controller:search,
        textInputAction:TextInputAction.search,
        onSubmitted:(_){offset=0;_reload();},
        decoration:InputDecoration(
          hintText:'Find by name, email or user ID',
          prefixIcon:const Icon(Icons.search_rounded),
          suffixIcon:IconButton(tooltip:'Search',icon:const Icon(Icons.arrow_forward_rounded),
            onPressed:(){offset=0;_reload();}))),
      const SizedBox(height:12),
      _ResultCount(count:data['total'],unit:'accounts'),
      const SizedBox(height:12),
      if(people.isEmpty)const AtsEmptyState(
        icon:Icons.person_search_outlined,title:'No matching accounts',
        description:'Try a different name, email or ID.')
      else for(final p in people)Padding(padding:const EdgeInsets.only(bottom:10),
        child:AtsPanel(onTap:()=>_openUser(p),padding:const EdgeInsets.all(16),
          child:Row(children:[
            CircleAvatar(radius:23,backgroundColor:AtsPalette.brand.withValues(alpha:.10),
              child:Text(_text(p['email'],'?').substring(0,1).toUpperCase(),
                style:const TextStyle(color:AtsPalette.brand,
                  fontWeight:FontWeight.w900,fontSize:18))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(_text(p['display_name'],'Unnamed account'),
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontWeight:FontWeight.w800)),
              const SizedBox(height:5),
              Text(_text(p['email']),maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:12,color:AtsPalette.muted)),
              const SizedBox(height:8),
              Wrap(spacing:6,runSpacing:5,children:[
                _Pill(_text(p['plan_code'],'free').toUpperCase(),AtsPalette.brand),
                _Pill(_text(p['account_status'],'active').toUpperCase(),
                  _stateColor(_text(p['account_status'],'active'))),
                if(p['role']=='admin')const _Pill('ADMIN',AtsPalette.warn),
              ]),
            ])),
            const Icon(Icons.chevron_right_rounded,color:AtsPalette.muted),
          ]))),
      _pager(total:data['total']),
    ]);
  }

  Widget _analyses(Map<String,dynamic> data){
    final list=AdminApi.rows(data['items']);
    const statuses=['','queued','extracting','parsing_job','scoring','recommending',
      'completed','failed','cancelled','expired'];
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      AtsPanel(padding:const EdgeInsets.symmetric(horizontal:15,vertical:4),
        child:DropdownButtonHideUnderline(child:DropdownButton<String>(
          isExpanded:true,value:statusFilter,
          items:statuses.map((x)=>DropdownMenuItem(
            value:x,child:Text(x.isEmpty?'All processing states':x.replaceAll('_',' ')))).toList(),
          onChanged:(v){if(v!=null)setState((){statusFilter=v;offset=0;_load();});},
        ))),
      const SizedBox(height:13),
      _ResultCount(count:data['total'],unit:'analyses'),
      const SizedBox(height:13),
      if(list.isEmpty)const AtsEmptyState(icon:Icons.rule_folder_outlined,
        title:'No analyses found',description:'Change the status filter to explore other jobs.')
      else for(final item in list)Padding(padding:const EdgeInsets.only(bottom:11),
        child:AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Expanded(child:Text(_text(item['job_title'],'Application analysis'),
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15))),
            AtsStatusChip(value:_text(item['status'],'queued')),
          ]),
          const SizedBox(height:10),
          Text('${_text(item['user_email'],'Unknown account')} · ${_date(item['created_at'])}',
            style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
          const SizedBox(height:13),
          Wrap(spacing:7,runSpacing:7,children:[
            _Pill('CV ${_text(item['ats_score'],'—')}/100',AtsPalette.brand),
            _Pill('MATCH ${_text(item['match_score'],'—')}/100',AtsPalette.ocean),
            if(item['failure_code']!=null)
              _Pill(_text(item['failure_code']),AtsPalette.danger),
            if(item['evaluator_version']!=null)
              _Pill(_text(item['evaluator_version']),AtsPalette.muted),
          ]),
          if(['queued','extracting','parsing_job','scoring','recommending']
              .contains(item['status']))...[
            const SizedBox(height:13),
            TextButton.icon(onPressed:()=>_cancelAnalysis(item),
              icon:const Icon(Icons.block_outlined,size:17),
              label:const Text('Cancel processing')),
          ],
        ]))),
      _pager(total:data['total']),
    ]);
  }

  Widget _plans(List<Map<String,dynamic>> plans){
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _Footnote('Plan limits control entitlements only. '
        'Billing, refunds, invoices and payment provider integration are not connected.'),
      const SizedBox(height:15),
      for(final plan in plans)Padding(padding:const EdgeInsets.only(bottom:13),
        child:AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Expanded(child:Text(_text(plan['name']),style:const TextStyle(
              fontSize:21,fontWeight:FontWeight.w900))),
            _Pill(plan['active']==true?'ACTIVE':'INACTIVE',
              plan['active']==true?AtsPalette.success:AtsPalette.muted),
          ]),
          const SizedBox(height:15),
          _Pair('Analyses each month',_number(plan['monthly_analysis_limit']),AtsPalette.brand),
          const Divider(height:22),
          _Pair('CV storage limit',_number(plan['saved_cv_limit']),AtsPalette.brand),
          const Divider(height:22),
          _Pair('History retention',
            plan['history_days']==null?'Unrestricted':'${_number(plan['history_days'])} days',
            AtsPalette.brand),
          const Divider(height:22),
          _Pair('PDF export',plan['pdf_export_enabled']==true?'Included':'Not included',
            AtsPalette.brand),
          const SizedBox(height:18),
          SizedBox(width:double.infinity,child:OutlinedButton.icon(
            icon:const Icon(Icons.tune_rounded),
            onPressed:()=>_editPlan(plan),label:const Text('Edit entitlements'))),
        ]))),
    ]);
  }

  Widget _audit(Map<String,dynamic> data){
    final logs=AdminApi.rows(data['items']);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _Footnote('Sensitive changes are recorded with an actor, reason and timestamp. '
        'Audit records are not editable from the client.'),
      const SizedBox(height:14),
      _ResultCount(count:data['total'],unit:'recorded actions'),
      const SizedBox(height:13),
      if(logs.isEmpty)const AtsEmptyState(icon:Icons.receipt_long_outlined,
        title:'No administrative events yet',
        description:'Plan changes and account actions will appear here.')
      else for(final item in logs)Padding(padding:const EdgeInsets.only(bottom:11),
        child:AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(Icons.gavel_outlined,color:AtsPalette.brand,size:20),
            const SizedBox(width:10),
            Expanded(child:Text(_text(item['action']).replaceAll('_',' '),
              style:const TextStyle(fontWeight:FontWeight.w800))),
            Text(_date(item['created_at']),style:const TextStyle(
              color:AtsPalette.muted,fontSize:11)),
          ]),
          const SizedBox(height:10),
          Text(_text(item['reason'],'No reason provided'),
            style:const TextStyle(fontSize:13,height:1.5)),
          const SizedBox(height:11),
          Text('Actor: ${_text(item['actor_id'])}',
            style:const TextStyle(color:AtsPalette.muted,fontSize:10)),
          if(item['target_id']!=null)Text('Target: ${_text(item['target_id'])}',
            style:const TextStyle(color:AtsPalette.muted,fontSize:10)),
        ]))),
      const SizedBox(height:9),
      OutlinedButton.icon(onPressed:logs.isEmpty?null:() async{
        final rows=logs.map((x)=>[
          _text(x['created_at']),_text(x['action']),_text(x['actor_id']),
          _text(x['target_id']),_text(x['reason']),
        ].map((s)=>'"'+s.replaceAll('"','""')+'"').join(',')).join('\n');
        await Clipboard.setData(ClipboardData(
          text:'"created_at","action","actor_id","target_id","reason"\n$rows'));
        _snack('Visible audit records copied as CSV.');
      },icon:const Icon(Icons.copy_all_outlined),
        label:const Text('Copy visible audit records')),
      _pager(total:data['total']),
    ]);
  }

  Widget _pager({required dynamic total}){
    final size=total is num?total.toInt():0;
    if(size<=limit)return const SizedBox.shrink();
    return Padding(padding:const EdgeInsets.only(top:15),child:Row(
      mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        OutlinedButton(onPressed:offset==0?null:()=>
          setState((){offset=(offset-limit).clamp(0,size);_load();}),
          child:const Text('Previous')),
        Text('${offset+1}–${(offset+limit).clamp(0,size)} / $size',
          style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
        OutlinedButton(onPressed:offset+limit>=size?null:()=>
          setState((){offset+=limit;_load();}),child:const Text('Next')),
      ]));
  }
}

class _Heading extends StatelessWidget{
  const _Heading({required this.title,required this.index});
  final String title;final int index;
  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsEyebrow('CV ATS / ADMINISTRATION'),
      const SizedBox(height:7),
      Text(title,style:Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight:FontWeight.w900,letterSpacing:-.7)),
      const SizedBox(height:7),
      Text(const [
        'Your operations, without the noise.',
        'Manage accounts with clear permissions.',
        'Inspect actual processing outcomes.',
        'Control benefits, not billing.',
        'Trace actions and accountability.',
      ][index],style:const TextStyle(color:AtsPalette.muted,height:1.5)),
    ]);
}
class _Metric extends StatelessWidget{
  const _Metric(this.title,this.value,this.icon,this.color);
  final String title,value;final IconData icon;final Color color;
  @override Widget build(BuildContext context)=>AtsPanel(padding:const EdgeInsets.all(15),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:color,size:22),
      const Spacer(),
      Text(value,style:Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight:FontWeight.w900)),
      const SizedBox(height:4),
      Text(title,style:const TextStyle(color:AtsPalette.muted,fontSize:11)),
    ]));
}
class _Pill extends StatelessWidget{
  const _Pill(this.label,this.color);
  final String label;final Color color;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
    decoration:BoxDecoration(color:color.withValues(alpha:.10),
      borderRadius:BorderRadius.circular(14)),
    child:Text(label.toUpperCase(),style:TextStyle(fontSize:9,
      color:color,fontWeight:FontWeight.w900,letterSpacing:.35)),
  );
}
class _Pair extends StatelessWidget{
  const _Pair(this.title,this.value,this.color);
  final String title,value;final Color color;
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.w700))),
    Text(value,style:TextStyle(color:color,fontWeight:FontWeight.w900)),
  ]);
}
class _Footnote extends StatelessWidget{
  const _Footnote(this.message);
  final String message;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(13),
    decoration:BoxDecoration(
      color:AtsPalette.brand.withValues(alpha:.07),
      borderRadius:BorderRadius.circular(12)),
    child:Row(children:[
      const Icon(Icons.info_outline,color:AtsPalette.brand,size:18),
      const SizedBox(width:10),
      Expanded(child:Text(message,style:const TextStyle(
        fontSize:12,height:1.5,color:AtsPalette.muted))),
    ]));
}
class _ResultCount extends StatelessWidget{
  const _ResultCount({required this.count,required this.unit});
  final dynamic count;final String unit;
  @override Widget build(BuildContext context)=>Text('${_number(count)} $unit',
    style:const TextStyle(color:AtsPalette.muted,fontWeight:FontWeight.w700,fontSize:12));
}
class _Busy extends StatelessWidget{
  const _Busy();
  @override Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.all(22),children:[
      const AtsEyebrow('LOADING OPERATIONS'),
      const SizedBox(height:15),
      for(var i=0;i<4;i++)Padding(
        padding:const EdgeInsets.only(bottom:12),
        child:AtsPanel(child:Row(children:[
          Container(width:44,height:44,decoration:BoxDecoration(
            color:AtsPalette.brand.withValues(alpha:.09),
            borderRadius:BorderRadius.circular(12))),
          const SizedBox(width:13),
          const Expanded(child:LinearProgressIndicator(minHeight:4)),
        ]))),
    ]);
}
class _Unavailable extends StatelessWidget{
  const _Unavailable({required this.message,required this.retry});
  final String message;final VoidCallback retry;
  @override Widget build(BuildContext context)=>Center(child:Padding(
    padding:const EdgeInsets.all(25),
    child:AtsEmptyState(icon:Icons.cloud_off_outlined,
      title:'Administration unavailable',description:message,
      action:FilledButton.icon(onPressed:retry,
        icon:const Icon(Icons.refresh),label:const Text('Try again')))));
}
