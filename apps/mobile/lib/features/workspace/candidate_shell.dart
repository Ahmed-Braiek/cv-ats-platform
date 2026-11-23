import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../main.dart' show NewAnalysisScreen;
import '../../ui/ats_design.dart';
import '../analysis/analysis_status_screen.dart';

class CandidateShell extends StatefulWidget {
  const CandidateShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<CandidateShell> createState() => _CandidateShellState();
}

class _CandidateShellState extends State<CandidateShell> {
  late int _tab;
  @override
  void initState() { super.initState(); _tab = widget.initialTab; }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(onAnalyze: () => setState(() => _tab = 1),
        onHistory: () => setState(() => _tab = 2)),
      const NewAnalysisScreen(),
      const AnalysisHistoryPage(),
      const CvLibraryPage(),
      const AccountPage(),
    ];
    const labels = ['Overview', 'Analyze', 'History', 'My CVs', 'Account'];
    const icons = [
      Icons.space_dashboard_outlined, Icons.auto_awesome_outlined,
      Icons.history_outlined, Icons.description_outlined,
      Icons.person_outline_rounded,
    ];
    const selected = [
      Icons.space_dashboard_rounded, Icons.auto_awesome,
      Icons.history_rounded, Icons.description_rounded,
      Icons.person_rounded,
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      return Scaffold(
        body: Row(children: [
          if (wide) NavigationRail(
            selectedIndex: _tab,
            minExtendedWidth: 210,
            extended: constraints.maxWidth >= 1100,
            onDestinationSelected: (value) => setState(() => _tab = value),
            leading: Padding(padding: const EdgeInsets.symmetric(vertical: 24),
              child: Icon(Icons.layers_rounded,
                size: 30, color: Theme.of(context).colorScheme.primary)),
            destinations: List.generate(labels.length, (i) =>
              NavigationRailDestination(
                icon: Icon(icons[i]), selectedIcon: Icon(selected[i]),
                label: Text(labels[i]),
              )),
          ),
          Expanded(child: IndexedStack(index: _tab, children: pages)),
        ]),
        bottomNavigationBar: wide ? null : NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: List.generate(labels.length, (i) =>
            NavigationDestination(
              icon: Icon(icons[i]), selectedIcon: Icon(selected[i]),
              label: labels[i],
            )),
        ),
      );
    });
  }
}

Future<List<Map<String,dynamic>>> _myRows(
  String table, String columns, String orderColumn,
) async {
  final user = SupabaseConfig.client.auth.currentUser;
  if(user == null) return [];
  final data = await SupabaseConfig.client
    .from(table).select(columns).eq('user_id', user.id)
    .order(orderColumn, ascending:false).limit(100);
  return (data as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
}

String _date(String? source) {
  if(source == null) return 'Date unavailable';
  final date = DateTime.tryParse(source)?.toLocal();
  if(date == null) return 'Date unavailable';
  return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key,required this.onAnalyze,required this.onHistory});
  final VoidCallback onAnalyze, onHistory;
  @override State<DashboardPage> createState()=>_DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<Map<String,dynamic>>> _analyses;
  @override void initState(){super.initState();_refresh();}
  void _refresh() => _analyses = _myRows(
    'analyses','id,status,created_at,completed_at','created_at');

  @override Widget build(BuildContext context) {
    final name = SupabaseConfig.configured
        ? (SupabaseConfig.client.auth.currentUser?.userMetadata?['display_name'] ?? 'there')
        : 'there';
    return AtsPage(title:'Your workspace',actions:[
      IconButton(
        tooltip:'Refresh overview', icon:const Icon(Icons.refresh_rounded),
        onPressed:()=>setState(_refresh),
      ),
    ],child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      AtsEyebrow('CANDIDATE DASHBOARD'),
      const SizedBox(height:8),
      Text('Welcome back, $name',style:Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      const Text('Your progress, clearer with every application.',
        style:TextStyle(color:AtsPalette.muted)),
      const SizedBox(height:23),
      Container(
        width:double.infinity,
        padding:const EdgeInsets.all(23),
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(24),
          gradient:const LinearGradient(
            colors:[AtsPalette.midnight,Color(0xFF294C9B)],
            begin:Alignment.topLeft,end:Alignment.bottomRight),
        ),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.auto_awesome,color:Color(0xFF82EBF6)),
          const SizedBox(height:12),
          const Text('Ready for your next opportunity?',
            style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          const Text('Compare your CV against any job description and understand what to improve.',
            style:TextStyle(color:Color(0xFFD5E6FF),height:1.45)),
          const SizedBox(height:22),
          FilledButton.icon(
            onPressed:widget.onAnalyze,
            icon:const Icon(Icons.add_rounded),
            label:const Text('New analysis'),
            style:FilledButton.styleFrom(
              foregroundColor:AtsPalette.midnight,backgroundColor:Colors.white),
          ),
        ]),
      ),
      const SizedBox(height:28),
      AtsSectionTitle('Your activity',subtitle:'Based on your saved analyses'),
      const SizedBox(height:14),
      FutureBuilder<List<Map<String,dynamic>>>(future:_analyses,builder:(context,snapshot){
        if(snapshot.connectionState != ConnectionState.done)
          return const Center(child:Padding(
            padding:EdgeInsets.all(25),child:CircularProgressIndicator()));
        if(snapshot.hasError)
          return AtsEmptyState(icon:Icons.wifi_off_rounded,
            title:'Cannot load your activity',
            description:'Check your connection and Supabase configuration.',
            action:TextButton(onPressed:()=>setState(_refresh),
              child:const Text('Try again')));
        final rows=snapshot.data ?? [];
        final completed=rows.where((x)=>x['status']=='completed').length;
        final pending=rows.where((x)=>!['completed','failed','cancelled','expired']
          .contains(x['status'])).length;
        return Column(children:[
          Row(children:[
            Expanded(child:AtsMetric(label:'Total analyses',value:'${rows.length}',
              icon:Icons.analytics_outlined)),
            const SizedBox(width:10),
            Expanded(child:AtsMetric(label:'Completed',value:'$completed',
              icon:Icons.verified_outlined,tint:AtsPalette.success)),
            const SizedBox(width:10),
            Expanded(child:AtsMetric(label:'In progress',value:'$pending',
              icon:Icons.hourglass_top_rounded,tint:AtsPalette.ocean)),
          ]),
          const SizedBox(height:28),
          AtsSectionTitle('Recent applications',
            subtitle:'Pick up where you left off',
            action:TextButton(onPressed:widget.onHistory,child:const Text('View all'))),
          const SizedBox(height:14),
          if(rows.isEmpty) AtsEmptyState(
            icon:Icons.document_scanner_outlined,
            title:'No analyses yet',
            description:'Upload a CV and a job description to get your first insights.',
            action:FilledButton(onPressed:widget.onAnalyze,
              child:const Text('Analyze a CV')),
          )else ...rows.take(4).map((r)=>Padding(
            padding:const EdgeInsets.only(bottom:10),
            child:_AnalysisTile(row:r))),
        ]);
      }),
    ]));
  }
}

class _AnalysisTile extends StatelessWidget {
  const _AnalysisTile({required this.row});
  final Map<String,dynamic> row;
  @override Widget build(BuildContext context)=> AtsPanel(
    padding:const EdgeInsets.all(16),
    onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(
      builder:(_)=>AnalysisStatusScreen(analysisId:row['id'] as String))),
    child:Row(children:[
      Container(
        padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:AtsPalette.brand.withValues(alpha:.08),
          borderRadius:BorderRadius.circular(14)),
        child:const Icon(Icons.article_outlined,color:AtsPalette.brand),
      ),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Application analysis',style:Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:4),
        Text(_date(row['created_at'] as String?),
          style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
      ])),
      AtsStatusChip(value:(row['status'] as String?)??'queued'),
      const Icon(Icons.chevron_right_rounded,color:AtsPalette.muted),
    ]),
  );
}

class AnalysisHistoryPage extends StatefulWidget {
  const AnalysisHistoryPage({super.key});
  @override State<AnalysisHistoryPage> createState()=>_AnalysisHistoryPageState();
}
class _AnalysisHistoryPageState extends State<AnalysisHistoryPage> {
  String filter='all';
  late Future<List<Map<String,dynamic>>> _history;
  @override void initState(){super.initState();_history=_myRows(
    'analyses','id,status,created_at,completed_at','created_at');}
  @override Widget build(BuildContext context)=>AtsPage(
    title:'Analysis history',
    actions:[IconButton(tooltip:'Refresh',onPressed:()=>setState(()=>
      _history=_myRows('analyses','id,status,created_at,completed_at','created_at')),
      icon:const Icon(Icons.refresh))],
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsHeader(title:'Your analysis history',
        subtitle:'Every assessment stays connected to your account.'),
      Wrap(spacing:8,children:[
        for(final item in ['all','completed','in progress','failed'])
          ChoiceChip(
            label:Text(item=='all'?'All':item=='in progress'?'In progress':
              item[0].toUpperCase()+item.substring(1)),
            selected:filter==item,
            onSelected:(_)=>setState(()=>filter=item),
          ),
      ]),
      const SizedBox(height:18),
      FutureBuilder<List<Map<String,dynamic>>>(future:_history,builder:(context,s){
        if(!s.hasData && !s.hasError)return const Center(
          child:Padding(padding:EdgeInsets.all(28),child:CircularProgressIndicator()));
        if(s.hasError)return const AtsEmptyState(icon:Icons.error_outline,
          title:'History unavailable',description:'Please retry when you are online.');
        final rows=(s.data ?? []).where((r){
          final status=r['status'] as String? ?? 'queued';
          if(filter=='all')return true;
          if(filter=='in progress')return !['completed','failed','cancelled','expired']
            .contains(status);
          return status==filter;
        }).toList();
        if(rows.isEmpty)return const AtsEmptyState(
          icon:Icons.history_rounded,title:'Nothing here yet',
          description:'Analyses matching this filter will appear here.');
        return Column(children:rows.map((r)=>Padding(
          padding:const EdgeInsets.only(bottom:12),
          child:_AnalysisTile(row:r))).toList());
      }),
    ]));
}

class CvLibraryPage extends StatefulWidget {
  const CvLibraryPage({super.key});
  @override State<CvLibraryPage> createState()=>_CvLibraryPageState();
}
class _CvLibraryPageState extends State<CvLibraryPage> {
  late Future<List<Map<String,dynamic>>> _documents;
  @override void initState(){super.initState();_load();}
  void _load()=>_documents=_myRows(
    'cvs','id,original_name,mime_type,size_bytes,storage_path,uploaded_at','uploaded_at');
  @override Widget build(BuildContext context)=>AtsPage(
    title:'CV library',
    actions:[IconButton(icon:const Icon(Icons.refresh),tooltip:'Refresh',
      onPressed:()=>setState(_load))],
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsHeader(title:'Your CV library',
        subtitle:'Your documents are stored in a private, access-controlled bucket.'),
      FutureBuilder<List<Map<String,dynamic>>>(future:_documents,builder:(context,s){
        if(!s.hasData && !s.hasError)return const Center(
          child:Padding(padding:EdgeInsets.all(28),child:CircularProgressIndicator()));
        if(s.hasError)return const AtsEmptyState(icon:Icons.lock_outline,
          title:'Unable to load documents',
          description:'Check your authentication and internet connection.');
        final items=s.data ?? [];
        if(items.isEmpty)return const AtsEmptyState(icon:Icons.folder_open_outlined,
          title:'No CVs uploaded',description:'Upload a CV from the Analyze tab to start your library.');
        return Column(children:[
          for(final file in items) Padding(
            padding:const EdgeInsets.only(bottom:12),
            child:AtsPanel(onTap:()=>showModalBottomSheet<void>(
              context:context,showDragHandle:true,
              builder:(ctx)=>SafeArea(child:Padding(
                padding:const EdgeInsets.all(24),
                child:Column(mainAxisSize:MainAxisSize.min,
                  crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const AtsEyebrow('PRIVATE DOCUMENT'),
                  const SizedBox(height:10),
                  Text(file['original_name'] as String? ?? 'CV',
                    style:Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height:13),
                  Text('Uploaded ${_date(file['uploaded_at'] as String?)}'),
                  const SizedBox(height:6),
                  Text('${((file['size_bytes'] as num? ?? 0)/1024).toStringAsFixed(0)} KB'),
                  const SizedBox(height:15),
                  const Text('Document preview and deletion controls will be enabled after secure file-lifecycle testing.',
                    style:TextStyle(color:AtsPalette.muted)),
                  const SizedBox(height:22),
                  OutlinedButton(onPressed:()=>Navigator.pop(ctx),
                    child:const Text('Close')),
                ]),
              ))),
            child:Row(children:[
              const Icon(Icons.description_outlined,color:AtsPalette.brand),
              const SizedBox(width:14),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(file['original_name'] as String? ?? 'Document',
                  maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontWeight:FontWeight.w700)),
                const SizedBox(height:5),
                Text(_date(file['uploaded_at'] as String?),
                  style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
              ])),
              const Icon(Icons.chevron_right_rounded,color:AtsPalette.muted),
            ])),
          ),
        ]);
      }),
    ]));
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override Widget build(BuildContext context) {
    final user=SupabaseConfig.client.auth.currentUser;
    if(user==null)return const AtsPage(title:'Account',child:AtsEmptyState(
      icon:Icons.person_off_outlined,title:'Sign in required',
      description:'Your account details appear after you sign in.'));
    return AtsPage(title:'Account',child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsHeader(title:'Account & preferences',
        subtitle:'Manage your profile, plan and privacy preferences.'),
      AtsPanel(child:Row(children:[
        CircleAvatar(radius:27,backgroundColor:AtsPalette.brand,
          child:Text((user.email??'?').substring(0,1).toUpperCase(),
            style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:21))),
        const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text((user.userMetadata?['display_name'] as String?)?.isNotEmpty == true
            ? (user.userMetadata!['display_name'] as String) : 'Candidate',
            style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          Text(user.email??'No email address',
            style:const TextStyle(color:AtsPalette.muted,fontSize:12)),
        ])),
      ])),
      const SizedBox(height:26),
      AtsSectionTitle('Subscription'),
      const SizedBox(height:12),
      AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const AtsEyebrow('MEMBERSHIP'),
        const SizedBox(height:9),
        const Text('Explore Free and Premium plans',
          style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        const SizedBox(height:8),
        const Text('See limits, features and current availability.',
          style:TextStyle(color:AtsPalette.muted)),
        const SizedBox(height:15),
        OutlinedButton.icon(
          icon:const Icon(Icons.workspace_premium_outlined),
          onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>const SubscriptionPlansPage())),
          label:const Text('Explore plans')),
      ])),
      const SizedBox(height:24),
      const AtsSectionTitle('Preferences & support'),
      const SizedBox(height:12),
      AtsPanel(padding:EdgeInsets.zero,child:Column(children:[
        ListTile(leading:const Icon(Icons.palette_outlined),
          title:const Text('Appearance'),subtitle:const Text('Light, dark or system'),
          trailing:const Icon(Icons.chevron_right),
          onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>const AppearancePage()))),
        const Divider(height:1),
        ListTile(leading:const Icon(Icons.help_outline_rounded),
          title:const Text('Help & FAQs'),trailing:const Icon(Icons.chevron_right),
          onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>const SupportPage()))),
        const Divider(height:1),
        ListTile(leading:const Icon(Icons.privacy_tip_outlined),
          title:const Text('Privacy & data'),trailing:const Icon(Icons.chevron_right),
          onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(
            builder:(_)=>const DataPrivacyPage()))),
      ])),
      const SizedBox(height:16),
      FutureBuilder<dynamic>(
        future:SupabaseConfig.client.from('profiles').select('role')
          .eq('id',user.id).maybeSingle(),
        builder:(context,s){
          final role = s.data is Map ? (s.data as Map)['role'] : null;
          if(role != 'admin')return const SizedBox.shrink();
          return Padding(padding:const EdgeInsets.only(bottom:16),
            child:AtsPanel(onTap:()=>Navigator.of(context).push(
              MaterialPageRoute<void>(builder:(_)=>const AdminConsolePage())),
              child:const ListTile(leading:Icon(Icons.admin_panel_settings),
                title:Text('Administrator console'),
                trailing:Icon(Icons.chevron_right))));
        }),
      OutlinedButton.icon(
        onPressed:() async {
          await SupabaseConfig.client.auth.signOut();
          // SessionGate observes the sign-out event and returns to login.
        },
        icon:const Icon(Icons.logout_rounded),label:const Text('Sign out')),
      const SizedBox(height:22),
      const Center(child:Text('CV ATS · Android first · v0.1',
        style:TextStyle(color:AtsPalette.muted,fontSize:11))),
    ]));
  }
}

class SubscriptionPlansPage extends StatelessWidget {
  const SubscriptionPlansPage({super.key});
  @override Widget build(BuildContext context)=>AtsPage(
    title:'Subscription plans',child:Column(children:[
      const AtsHeader(title:'Choose your way to improve',
        subtitle:'Your current plan and limits are managed by the server.'),
      FutureBuilder<dynamic>(
        future:SupabaseConfig.client.from('subscription_plans').select(
          'code,name,monthly_analysis_limit,saved_cv_limit,history_days,pdf_export_enabled'
        ).eq('active',true).order('monthly_analysis_limit'),
        builder:(context,s){
          if(!s.hasData && !s.hasError)return const CircularProgressIndicator();
          if(s.hasError)return const AtsEmptyState(icon:Icons.cloud_off,
            title:'Plans unavailable',description:'Try again when the network is available.');
          final rows=(s.data as List? ?? []);
          return Column(children:[
            for(final data in rows)Padding(
              padding:const EdgeInsets.only(bottom:14),
              child:AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                AtsEyebrow((data['code'] as String?)=='premium'?'MORE FLEXIBILITY':'GET STARTED'),
                const SizedBox(height:10),
                Text(data['name']?.toString()??'Plan',
                  style:Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight:FontWeight.w900)),
                const SizedBox(height:14),
                Text('${data['monthly_analysis_limit']} analyses / month'),
                const SizedBox(height:6),
                Text('${data['saved_cv_limit']} saved CVs'),
                const SizedBox(height:6),
                Text(data['pdf_export_enabled']==true?'PDF report export included':
                  'PDF report export not included'),
                const SizedBox(height:20),
                if(data['code']=='premium')
                  const FilledButton(onPressed:null,
                    child:Text('Upgrade — billing not enabled yet'))
                else const Chip(label:Text('Free tier available')),
              ])),
            ),
            const Text('Payment processing is not connected. No payment will be collected.',
              style:TextStyle(color:AtsPalette.muted,fontSize:12)),
          ]);
        }),
    ]));
}

class AppearancePage extends StatelessWidget{
  const AppearancePage({super.key});
  @override Widget build(BuildContext context)=>AtsPage(title:'Appearance',child:Column(children:[
    const AtsHeader(title:'Make it yours',
      subtitle:'Choose the theme used throughout the app.'),
    for(final entry in <(String,ThemeMode)>[
      ('Use device setting',ThemeMode.system),
      ('Light mode',ThemeMode.light),
      ('Dark mode',ThemeMode.dark),
    ]) ValueListenableBuilder<ThemeMode>(
      valueListenable:AtsAppearance.mode,
      builder:(context,mode,_)=>RadioListTile<ThemeMode>(
        title:Text(entry.$1),value:entry.$2,groupValue:mode,
        onChanged:(value){if(value!=null) AtsAppearance.mode.value=value;},
      )),
    const SizedBox(height:8),
    const Text('Theme selection lasts for this app session. Saved preferences are coming later.',
      style:TextStyle(color:AtsPalette.muted,fontSize:12)),
  ]));
}

class SupportPage extends StatelessWidget{
  const SupportPage({super.key});
  @override Widget build(BuildContext context)=>AtsPage(title:'Help & FAQs',
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsHeader(title:'How can we help?',
        subtitle:'Answers to the most common CV ATS questions.'),
      for(final faq in <(String,String)>[
        ('What is the ATS score?',
          'An explainable document-format and section-structure assessment. It is not a score from a specific employer system.'),
        ('What is Job Match?',
          'A separate comparison of CV evidence against explicitly extracted job requirements. It is not a hiring prediction.'),
        ('What documents are supported?',
          'PDF, DOCX and common PNG/JPEG images up to 10 MB. Images and scanned PDFs may require AI document understanding.'),
        ('Can AI change or invent my experience?',
          'No. The system should only recommend accurate improvements and never fabricate qualifications.'),
        ('Where are my uploaded CVs stored?',
          'In a private Supabase Storage bucket protected with account-specific access rules.'),
        ('Why is analysis pending?',
          'Documents are queued for backend processing. Gemini limits and processing errors can delay the result.'),
      ]) AtsPanel(padding:EdgeInsets.zero,child:ExpansionTile(
        title:Text(faq.$1,style:const TextStyle(fontWeight:FontWeight.w700)),
        children:[Padding(padding:const EdgeInsets.fromLTRB(18,0,18,20),
          child:Text(faq.$2,style:const TextStyle(color:AtsPalette.muted)))],
      )),
    ]));
}

class DataPrivacyPage extends StatelessWidget{
  const DataPrivacyPage({super.key});
  @override Widget build(BuildContext context)=>AtsPage(title:'Privacy & data',
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const AtsHeader(title:'Your documents, your control',
        subtitle:'CVs contain sensitive personal details.'),
      const AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        AtsEyebrow('PRIVATE BY DESIGN'),
        SizedBox(height:10),
        Text('Uploaded documents are placed in a private storage bucket and associated with your account.'),
        SizedBox(height:12),
        Text('Gemini processing may transmit CV contents to Google. Until privacy terms and consent are finalized, use synthetic or explicitly authorized documents.'),
      ])),
      const SizedBox(height:18),
      const AtsSectionTitle('Account deletion'),
      const SizedBox(height:10),
      const AtsEmptyState(
        icon:Icons.delete_outline,
        title:'Self-service deletion is not active yet',
        description:'We will enable account and file deletion only after backend deletion, retention and audit handling are implemented and tested.'),
    ]));
}

class AdminConsolePage extends StatefulWidget{
  const AdminConsolePage({super.key});
  @override State<AdminConsolePage> createState()=>_AdminConsolePageState();
}
class _AdminConsolePageState extends State<AdminConsolePage>{
  int selected=0;
  @override Widget build(BuildContext context)=>AtsPage(
    title:'Administrator',child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        const AtsHeader(title:'Platform administration',
          subtitle:'Administration screens require server-enforced permissions.'),
        Wrap(spacing:8,children:[
          for(int i=0;i<4;i++)ChoiceChip(label:Text(
            const ['Overview','Users','Plans & limits','Statistics'][i]),
            selected:i==selected,onSelected:(_)=>setState(()=>selected=i)),
        ]),
        const SizedBox(height:20),
        AtsEmptyState(
          icon:const [
            Icons.dashboard_customize_outlined,Icons.group_outlined,
            Icons.tune_rounded,Icons.insights_outlined,
          ][selected],
          title:const ['Overview','User management','Plan management','System statistics'][selected],
          description:'The administrator API and role-enforced data views are not connected yet. No simulated user data or fabricated metrics are displayed.',
        ),
      ]));
}
