import 'package:flutter/material.dart';
import '../../ui/ats_design.dart';
import 'admin_api.dart';

String _label(dynamic value,[String missing='—']) =>
    value==null||value.toString().trim().isEmpty?missing:value.toString();

class AdminUserSheet extends StatefulWidget{
  const AdminUserSheet({super.key,required this.user});
  final Map<String,dynamic> user;
  @override State<AdminUserSheet> createState()=>_AdminUserSheetState();
}
class _AdminUserSheetState extends State<AdminUserSheet>{
  late String plan,status;
  final reason=TextEditingController();
  bool busy=false,changed=false;
  @override void initState(){
    super.initState();
    plan=_label(widget.user['plan_code'],'free');
    status=_label(widget.user['account_status'],'active');
  }
  @override void dispose(){reason.dispose();super.dispose();}
  void _toast(String text,{bool error=false}){
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(text),backgroundColor:error?AtsPalette.danger:null));
  }
  bool get eligible=>widget.user['role']=='candidate';
  bool get reasonValid=>reason.text.trim().length>=8;
  Future<void> _execute(String action,Map<String,dynamic> extra) async{
    if(busy)return;
    if(!reasonValid){_toast('Please enter a reason of at least 8 characters.',error:true);return;}
    setState(()=>busy=true);
    try{
      await AdminApi.call(action,{
        'userId':widget.user['id'],'reason':reason.text.trim(),...extra,
      });
      if(!mounted)return;
      setState((){
        changed=true;
        if(action=='grant_plan')plan=extra['plan'] as String;
        if(action=='suspend')status='suspended';
        if(action=='restore')status='active';
        reason.clear();
      });
      _toast('Change saved and added to the audit trail.');
    }catch(error){if(mounted)_toast('$error',error:true);}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _confirmDelete()async{
    if(!eligible||busy)return;
    final email=TextEditingController(),explanation=TextEditingController();
    final address=_label(widget.user['email'],'');
    var enabled=false;
    final approved=await showDialog<bool>(context:context,builder:(dialogCtx)=>
      StatefulBuilder(builder:(dialogCtx,refresh)=>AlertDialog(
        title:const Text('Delete this account permanently?'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('This removes the account, its CV files, analyses, '
            'results and membership history. This cannot be undone.',
            style:TextStyle(height:1.5)),
          const SizedBox(height:15),
          Text('Type the complete email to confirm: $address',
            style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:9),
          TextField(controller:email,autofillHints:const [],
            decoration:const InputDecoration(labelText:'Confirm account email'),
            onChanged:(_)=>refresh(()=>enabled=email.text.trim().toLowerCase()==
              address.toLowerCase()&&explanation.text.trim().length>=8)),
          const SizedBox(height:11),
          TextField(controller:explanation,maxLength:500,
            decoration:const InputDecoration(labelText:'Reason (required)'),
            onChanged:(_)=>refresh(()=>enabled=email.text.trim().toLowerCase()==
              address.toLowerCase()&&explanation.text.trim().length>=8)),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogCtx,false),
            child:const Text('Keep account')),
          FilledButton(
            style:FilledButton.styleFrom(backgroundColor:AtsPalette.danger),
            onPressed:enabled?()=>Navigator.pop(dialogCtx,true):null,
            child:const Text('Permanently delete')),
        ],
      )));
    final confirmedEmail=email.text.trim();
    final confirmedReason=explanation.text.trim();
    email.dispose();explanation.dispose();
    if(approved!=true||!mounted)return;
    setState(()=>busy=true);
    try{
      await AdminApi.call('delete_user',{
        'userId':widget.user['id'],
        'confirmEmail':confirmedEmail,'confirm':'DELETE','reason':confirmedReason,
      });
      if(mounted){
        _toast('Account deleted.');
        Navigator.of(context).pop(true);
      }
    }catch(error){
      if(mounted)_toast('Deletion not completed. $error',error:true);
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }
  @override Widget build(BuildContext context){
    final textColor=Theme.of(context).colorScheme.onSurface;
    return SafeArea(child:Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),
      child:SizedBox(height:MediaQuery.sizeOf(context).height*.84,
        child:ListView(padding:const EdgeInsets.fromLTRB(21,9,21,33),children:[
          Row(children:[
            const AtsEyebrow('ACCOUNT INSPECTOR'),
            const Spacer(),
            IconButton(tooltip:'Close',icon:const Icon(Icons.close_rounded),
              onPressed:()=>Navigator.pop(context,changed)),
          ]),
          const SizedBox(height:12),
          Row(children:[
            CircleAvatar(radius:28,backgroundColor:AtsPalette.brand.withValues(alpha:.10),
              child:Text(_label(widget.user['email'],'?').substring(0,1).toUpperCase(),
                style:const TextStyle(color:AtsPalette.brand,
                  fontSize:21,fontWeight:FontWeight.w900))),
            const SizedBox(width:15),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(_label(widget.user['display_name'],'Unnamed account'),
                style:Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight:FontWeight.w900)),
              const SizedBox(height:5),
              Text(_label(widget.user['email']),style:const TextStyle(
                color:AtsPalette.muted,fontSize:12)),
            ])),
          ]),
          const SizedBox(height:19),
          Wrap(spacing:7,runSpacing:7,children:[
            Chip(label:Text(_label(widget.user['role']).toUpperCase())),
            Chip(label:Text(plan.toUpperCase())),
            Chip(label:Text(status.toUpperCase())),
          ]),
          const SizedBox(height:14),
          AtsPanel(child:Column(children:[
            _Detail('User ID',_label(widget.user['id'])),
            const Divider(height:22),
            _Detail('Verified email',widget.user['email_confirmed_at']!=null?'Yes':'Not yet'),
            const Divider(height:22),
            _Detail('Analyses',_label(widget.user['analysis_count'],'0')),
            const Divider(height:22),
            _Detail('Saved CVs',_label(widget.user['cv_count'],'0')),
            const Divider(height:22),
            _Detail('Created',_label(widget.user['created_at'])),
          ])),
          const SizedBox(height:22),
          const AtsSectionTitle('Account actions',
            subtitle:'Actions require an audit reason and server-side authorization.'),
          const SizedBox(height:13),
          if(!eligible)const AtsPanel(child:Text(
            'Administrator accounts are protected. '
            'Role changes and removal require a separate owner-controlled process.',
            style:TextStyle(height:1.5,color:AtsPalette.muted)))
          else ...[
            TextField(controller:reason,maxLines:2,maxLength:500,
              onChanged:(_)=>setState((){}),
              decoration:const InputDecoration(
                labelText:'Reason for the change',hintText:'Describe the support or policy reason')),
            const SizedBox(height:12),
            AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const AtsEyebrow('SUBSCRIPTION ENTITLEMENT'),
              const SizedBox(height:8),
              const Text('Manually assign Free or Premium. No payment is charged.',
                style:TextStyle(color:AtsPalette.muted,fontSize:12,height:1.5)),
              const SizedBox(height:13),
              DropdownButtonFormField<String>(
                initialValue:plan,
                decoration:const InputDecoration(labelText:'Assigned plan'),
                items:const [
                  DropdownMenuItem(value:'free',child:Text('Free')),
                  DropdownMenuItem(value:'premium',child:Text('Premium')),
                ],
                onChanged:busy?null:(value){if(value!=null)setState(()=>plan=value);},
              ),
              const SizedBox(height:13),
              SizedBox(width:double.infinity,child:FilledButton.icon(
                onPressed:busy||!reasonValid?null:()=>_execute(
                  'grant_plan',{'plan':plan}),
                icon:const Icon(Icons.check_rounded),
                label:Text(busy?'Saving…':'Apply membership'))),
            ])),
            const SizedBox(height:13),
            AtsPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const AtsEyebrow('ACCESS CONTROL'),
              const SizedBox(height:7),
              Text(status=='suspended'
                ?'Account sign-ins are restricted. Existing access tokens may remain valid until expiry.'
                :'Suspend new sign-ins if an account requires investigation.',
                style:TextStyle(color:textColor.withValues(alpha:.67),
                  height:1.55,fontSize:12)),
              const SizedBox(height:13),
              SizedBox(width:double.infinity,child:OutlinedButton.icon(
                onPressed:busy||!reasonValid?null:()=>_execute(
                  status=='suspended'?'restore':'suspend',{}),
                icon:Icon(status=='suspended'
                  ?Icons.lock_open_outlined:Icons.block_outlined),
                label:Text(status=='suspended'?'Restore sign-in':'Suspend sign-in'))),
            ])),
            const SizedBox(height:15),
            Container(padding:const EdgeInsets.all(17),
              decoration:BoxDecoration(
                color:AtsPalette.danger.withValues(alpha:.07),
                borderRadius:BorderRadius.circular(17)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Danger zone',style:TextStyle(
                  color:AtsPalette.danger,fontWeight:FontWeight.w900,fontSize:17)),
                const SizedBox(height:8),
                const Text('Deleting an account permanently removes its app data '
                  'and private CVs. A second typed-email confirmation is mandatory.',
                  style:TextStyle(fontSize:12,height:1.55)),
                const SizedBox(height:13),
                OutlinedButton.icon(onPressed:busy?null:_confirmDelete,
                  icon:const Icon(Icons.delete_forever_outlined),
                  style:OutlinedButton.styleFrom(foregroundColor:AtsPalette.danger),
                  label:const Text('Delete account permanently')),
              ])),
          ],
        ]),
      ),
    ));
  }
}
class _Detail extends StatelessWidget{
  const _Detail(this.label,this.value);
  final String label,value;
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(flex:2,child:Text(label,
      style:const TextStyle(color:AtsPalette.muted,fontSize:12))),
    Expanded(flex:3,child:Text(value,maxLines:2,overflow:TextOverflow.ellipsis,
      textAlign:TextAlign.right,
      style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12))),
  ]);
}
