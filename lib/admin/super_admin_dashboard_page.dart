import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_gate.dart';

class SuperAdminDashboardPage extends StatefulWidget {
 const SuperAdminDashboardPage({super.key});
 @override State<SuperAdminDashboardPage> createState()=>_SuperAdminDashboardPageState();
}
class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
 Future<void> refresh() async { if(mounted)setState((){}); }
 Future<void> signOut() async { await FirebaseAuth.instance.signOut(); if(mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const AdminGate()),(_)=>false); }
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFFEAF8EF),
  appBar:AppBar(title:const Text('PlayPlace Super Admin'),actions:[IconButton(onPressed:refresh,icon:const Icon(Icons.refresh)),IconButton(onPressed:signOut,icon:const Icon(Icons.logout))]),
  body:Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFF2FBF5),Color(0xFFE2F4E8),Color(0xFFD5EEDD)])),
   child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:ListView(padding:const EdgeInsets.all(22),children:[
    const Text('Platform control center',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:Color(0xFF17452D))),
    const Text('Approve administrators and manage subscription plans.',style:TextStyle(color:Color(0xFF64816D))),
    const SizedBox(height:22),
    Row(children:[const Expanded(child:Text('Subscription packages',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700))),FilledButton.icon(onPressed:()=>showDialog(context:context,builder:(_)=>const _PackageDialog()),icon:const Icon(Icons.add),label:const Text('Create package'))]),
    const SizedBox(height:10),_Packages(onChanged:refresh),
    const SizedBox(height:24),const Text('Administrator accounts',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
    const SizedBox(height:10),_Admins(onChanged:refresh),
    const SizedBox(height:24),const Text('Pending invitations',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
    const SizedBox(height:10),_Invitations(),
   ])))),
 );
}
class _Packages extends StatelessWidget {
 const _Packages({required this.onChanged}); final VoidCallback onChanged;
 @override Widget build(BuildContext context)=>FutureBuilder<QuerySnapshot<Map<String,dynamic>>>(
  future:FirebaseFirestore.instance.collection('subscriptionPackages').orderBy('createdAt',descending:true).get(),
  builder:(context,s){if(s.hasError)return Text('Could not load packages: ${s.error}');if(!s.hasData)return const LinearProgressIndicator();final docs=s.data!.docs;
   if(docs.isEmpty)return const _Panel(child:Text('No packages yet. Create your first subscription package.'));
   return Column(children:[for(final d in docs)Padding(padding:const EdgeInsets.only(bottom:8),child:_Panel(child:ListTile(contentPadding:EdgeInsets.zero,
    leading:const CircleAvatar(backgroundColor:Color(0xFFDDF2E3),child:Icon(Icons.card_membership,color:Color(0xFF328B55))),
    title:Text('${d.data()['name']??'Package'}',style:const TextStyle(fontWeight:FontWeight.w700)),
    subtitle:Text('₹${d.data()['price']??0} · ${d.data()['durationDays']??30} days · ${d.data()['maxBuses']??1} buses · ${d.data()['active']==true?'Active':'Disabled'}'),
    trailing:Wrap(mainAxisSize:MainAxisSize.min,children:[
     IconButton(tooltip:'Edit',onPressed:()=>showDialog(context:context,builder:(_)=>_PackageDialog(id:d.id,data:d.data())),icon:const Icon(Icons.edit_outlined)),
     IconButton(tooltip:'Enable/disable',onPressed:()=>d.reference.update({'active':d.data()['active']!=true}),icon:Icon(d.data()['active']==true?Icons.pause_circle_outline:Icons.play_circle_outline)),
     IconButton(tooltip:'Delete',onPressed:()=>d.reference.delete(),icon:const Icon(Icons.delete_outline,color:Colors.redAccent))
    ]))))]);
  });
}
class _PackageDialog extends StatefulWidget {
 const _PackageDialog({this.id,this.data}); final String?id;final Map<String,dynamic>?data;
 @override State<_PackageDialog>createState()=>_PackageDialogState();
}
class _PackageDialogState extends State<_PackageDialog>{
 late final name=TextEditingController(text:widget.data?['name']?.toString()??'');
 late final price=TextEditingController(text:widget.data?['price']?.toString()??'');
 late final days=TextEditingController(text:widget.data?['durationDays']?.toString()??'30');
 late final buses=TextEditingController(text:widget.data?['maxBuses']?.toString()??'1');
 late final features=TextEditingController(text:(widget.data?['features'] as List?)?.join(', ')??'');
 bool active=true,saving=false;
 @override void initState(){super.initState();active=widget.data?['active']!=false;}
 @override void dispose(){name.dispose();price.dispose();days.dispose();buses.dispose();features.dispose();super.dispose();}
 Future<void>save()async{
  final n=name.text.trim(),p=double.tryParse(price.text.trim()),d=int.tryParse(days.text.trim()),b=int.tryParse(buses.text.trim());
  if(n.isEmpty||p==null||p<0||d==null||d<1||b==null||b<1)return;
  setState(()=>saving=true);
  try{final data={'name':n,'price':p,'durationDays':d,'maxBuses':b,'features':features.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList(),'active':active,'updatedAt':FieldValue.serverTimestamp()};
   final col=FirebaseFirestore.instance.collection('subscriptionPackages');
   if(widget.id==null){await col.add({...data,'createdAt':FieldValue.serverTimestamp()});}else{await col.doc(widget.id).update(data);}
   if(mounted)Navigator.pop(context);
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save package: $e')));}
  finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.id==null?'Create subscription package':'Edit subscription package'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  TextField(controller:name,decoration:const InputDecoration(labelText:'Package name')),
  TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Price (₹)')),
  TextField(controller:days,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Duration (days)')),
  TextField(controller:buses,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Maximum buses')),
  TextField(controller:features,maxLines:2,decoration:const InputDecoration(labelText:'Features (comma separated)')),
  SwitchListTile(value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Package active'))
 ]))),actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save package'))]);
}
class _Admins extends StatelessWidget {
 const _Admins({required this.onChanged});final VoidCallback onChanged;
 @override Widget build(BuildContext context)=>FutureBuilder<QuerySnapshot<Map<String,dynamic>>>(
  future:FirebaseFirestore.instance.collection('admins').get(),
  builder:(context,s){if(s.hasError)return Text('Could not load administrators: ${s.error}');if(!s.hasData)return const LinearProgressIndicator();final docs=s.data!.docs;
   if(docs.isEmpty)return const _Panel(child:Text('No administrator accounts yet.'));
   return Column(children:[for(final d in docs)Padding(padding:const EdgeInsets.only(bottom:8),child:_AdminTile(doc:d,onChanged:onChanged))]);
  });
}
class _AdminTile extends StatelessWidget {
 const _AdminTile({required this.doc,required this.onChanged});final QueryDocumentSnapshot<Map<String,dynamic>> doc;final VoidCallback onChanged;
 @override Widget build(BuildContext context){final data=doc.data();final sub=data['subscription'] is Map?Map<String,dynamic>.from(data['subscription']):<String,dynamic>{};
  return _Panel(child:ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Icon(data['active']==true?Icons.person:Icons.person_off_outlined)),
   title:Text(data['email']?.toString()??doc.id),subtitle:Text('Status: ${data['active']==true?'Active':(data['approvalStatus']=='pending'?'Awaiting approval':(data['approvalStatus']=='rejected'?'Rejected':'Disabled'))} · Plan: ${sub['packageName']??'No plan'}'),
   trailing:PopupMenuButton<String>(onSelected:(v)async{
    if(v=='approve'){await doc.reference.update({'active':true,'approvalStatus':'approved','approvedAt':FieldValue.serverTimestamp()});onChanged();}\n    if(v=='reject'){await doc.reference.update({'active':false,'approvalStatus':'rejected','rejectedAt':FieldValue.serverTimestamp()});onChanged();}\n    if(v=='toggle'){await doc.reference.update({'active':data['active']!=true});onChanged();}
    if(v=='assign'){final plans=await FirebaseFirestore.instance.collection('subscriptionPackages').where('active',isEqualTo:true).get();if(context.mounted)showDialog(context:context,builder:(_)=>_AssignDialog(admin:doc,packages:plans.docs,onChanged:onChanged));}
   },itemBuilder:(_)=>[if(data['approvalStatus']=='pending')const PopupMenuItem(value:'approve',child:Text('Approve admin')),if(data['approvalStatus']=='pending')const PopupMenuItem(value:'reject',child:Text('Reject admin')),if(data['approvalStatus']!='pending')PopupMenuItem(value:'toggle',child:Text(data['active']==true?'Disable admin':'Enable admin')),const PopupMenuItem(value:'assign',child:Text('Assign subscription'))])));
 }
}
class _AssignDialog extends StatefulWidget{
 const _AssignDialog({required this.admin,required this.packages,required this.onChanged});final QueryDocumentSnapshot<Map<String,dynamic>> admin;final List<QueryDocumentSnapshot<Map<String,dynamic>>> packages;final VoidCallback onChanged;
 @override State<_AssignDialog>createState()=>_AssignDialogState();
}
class _AssignDialogState extends State<_AssignDialog>{
 String?selected;bool saving=false;
 Future<void>save()async{if(selected==null)return;setState(()=>saving=true);try{
  final p=widget.packages.firstWhere((x)=>x.id==selected),d=p.data(),duration=(d['durationDays'] as num?)?.toInt()??30,now=DateTime.now();
  await widget.admin.reference.update({'subscription':{'packageId':p.id,'packageName':d['name'],'price':d['price'],'maxBuses':d['maxBuses'],'features':d['features']??[],'startedAt':Timestamp.fromDate(now),'expiresAt':Timestamp.fromDate(now.add(Duration(days:duration))),'status':'active'}});
  if(mounted){Navigator.pop(context);widget.onChanged();}
 }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not assign subscription: $e')));}finally{if(mounted)setState(()=>saving=false);}}
 @override Widget build(BuildContext context)=>AlertDialog(title:const Text('Assign subscription'),content:SizedBox(width:360,child:widget.packages.isEmpty?const Text('Create an active package first.'):DropdownButtonFormField<String>(value:selected,decoration:const InputDecoration(labelText:'Package'),items:[for(final p in widget.packages)DropdownMenuItem(value:p.id,child:Text('${p.data()['name']} · ₹${p.data()['price']}'))],onChanged:(v)=>setState(()=>selected=v))),actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:saving||widget.packages.isEmpty?null:save,child:const Text('Assign'))]);
}
class _Invitations extends StatelessWidget{
 @override Widget build(BuildContext context)=>FutureBuilder<QuerySnapshot<Map<String,dynamic>>>(future:FirebaseFirestore.instance.collection('adminInvites').where('status',isEqualTo:'pending').get(),builder:(context,s){
  if(s.hasError)return Text('Could not load invitations: ${s.error}');if(!s.hasData)return const LinearProgressIndicator();final docs=s.data!.docs;
  if(docs.isEmpty)return const _Panel(child:Text('No pending administrator invitations.'));
  return _Panel(child:Column(children:[for(final d in docs)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.mail_outline,color:Color(0xFF328B55)),title:Text(d.id),subtitle:const Text('Waiting for the invited user to register'),trailing:IconButton(onPressed:()=>d.reference.delete(),icon:const Icon(Icons.delete_outline,color:Colors.redAccent)))]));
 });
}
class _Panel extends StatelessWidget{
 const _Panel({required this.child});final Widget child;
 @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.78),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF80B996).withValues(alpha:.3))),child:child);
}
