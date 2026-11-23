import 'dart:async';
import 'package:flutter/material.dart';
import 'analysis_api.dart';

class AnalysisStatusScreen extends StatefulWidget {
  const AnalysisStatusScreen({required this.analysisId,super.key});
  final String analysisId;
  @override
  State<AnalysisStatusScreen> createState()=>_AnalysisStatusScreenState();
}

class _AnalysisStatusScreenState extends State<AnalysisStatusScreen> {
  Timer? _timer;
  Map<String,dynamic>? _data;
  String? _error;
  bool _loading=true;
  bool _inFlight=false;

  @override
  void initState(){
    super.initState();
    _refresh();
    _timer=Timer.periodic(const Duration(seconds:5),(_)=>_refresh());
  }
  Future<void> _refresh() async {
    if (_inFlight) return;
    _inFlight=true;
    try {
      final data=await AnalysisApi.results(widget.analysisId);
      if(!mounted)return;
      setState((){_data=data;_error=null;_loading=false;});
      final status=(data['analysis'] as Map<String,dynamic>)['status'];
      if(data['ready']==true || ['failed','expired','cancelled'].contains(status)){
        _timer?.cancel();
      }
    }catch(e){
      if(mounted)setState((){_error='Unable to refresh processing status';_loading=false;});
    }finally{_inFlight=false;}
  }
  @override
  void dispose(){_timer?.cancel();super.dispose();}
  @override
  Widget build(BuildContext context){
    final analysis=_data?['analysis'] as Map<String,dynamic>?;
    final completed=_data?['ready']==true;
    final recommendations=(_data?['recommendations'] as List<dynamic>?)??[];
    return Scaffold(
      appBar:AppBar(title:const Text('Analysis results')),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:700),
        child:ListView(padding:const EdgeInsets.all(20),children:[
          if(_loading)const LinearProgressIndicator(),
          if(_error!=null)...[
            Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
            TextButton(onPressed:_refresh,child:const Text('Retry')),
          ],
          Text(completed?'Your CV analysis is ready':'Analyzing your application',
            style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:12),
          Text('Status: ${analysis?['status'] ?? 'loading'}'),
          const SizedBox(height:24),
          if(completed)...[
            _ScoreCard(title:'ATS compatibility',
              value:(_data!['ats'] as Map<String,dynamic>)['overall'] as int),
            _ScoreCard(title:'Job Match',
              value:(_data!['match'] as Map<String,dynamic>)['overall'] as int),
            const SizedBox(height:22),
            Text('Recommendations',style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:10),
            for(final item in recommendations)
              Card(child:ListTile(
                title:Text((item as Map<String,dynamic>)['message'] as String? ?? ''),
                subtitle:Text(item['category'] as String? ?? ''),
              )),
            const SizedBox(height:14),
            const Text('Scores use an experimental, explainable rubric and do not predict hiring outcomes.',
              style:TextStyle(color:Colors.black54)),
          ] else if(['failed','expired','cancelled'].contains(analysis?['status']))...[
            const Text('Processing could not finish. Please retry later.'),
          ]else const Text('We will refresh this page automatically.'),
        ]),
      ))),
    );
  }
}
class _ScoreCard extends StatelessWidget{
  const _ScoreCard({required this.title,required this.value});
  final String title;
  final int value;
  @override
  Widget build(BuildContext context)=>Card(
    child:Padding(padding:const EdgeInsets.all(20),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:10),
        Text('$value / 100',style:Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        LinearProgressIndicator(value:value/100),
      ])),
  );
}
