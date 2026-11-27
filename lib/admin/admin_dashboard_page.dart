import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_gate.dart';
class AdminDashboardPage extends StatefulWidget{
 const AdminDashboardPage({super.key});
 @override State<AdminDashboardPage> createState()=>_AdminDashboardPageState();
}
class _AdminDashboardPageState extends State<AdminDashboardPage>{
 late Future<QuerySnapshot<Map<String,dynamic>>> _busesFuture;
 Timer? _refreshTimer;
 int _refreshVersion=0;
 Future<QuerySnapshot<Map<String,dynamic>>> _fetchBuses()=>FirebaseFirestore.instance.collection('buses').orderBy('createdAt',descending:true).get();
 @override void initState(){super.initState();_busesFuture=_fetchBuses();_refreshTimer=Timer.periodic(const Duration(seconds:15),(_)=>_refresh());}
 @override void dispose(){_refreshTimer?.cancel();super.dispose();}
 void _refresh(){if(!mounted)return;setState(()=>{_busesFuture=_fetchBuses();_refreshVersion++;});}
 @override Widget build(BuildContext context){
  return Scaffold(backgroundColor:const Color(0xFFEAF8EF),appBar:AppBar(title:const Text('PlayPlace Admin'),actions:[
   TextButton.icon(onPressed:()=>showDialog(context:context,builder:(_)=>const _InviteDialog()),icon:const Icon(Icons.person_add_alt_1),label:const Text('Invite admin')),
   IconButton(tooltip:'Refresh dashboard',onPressed:_refresh,icon:const Icon(Icons.refresh)),
   IconButton(onPressed:()async{await FirebaseAuth.instance.signOut();if(context.mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const AdminGate()),(_)=>false);},icon:const Icon(Icons.logout)),const SizedBox(width:8)]),
   body:Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFF2FBF5),Color(0xFFE2F4E8),Color(0xFFD5EEDD)])),
    child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     const Text('Fleet overview',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:Color(0xFF17452D))),
     const Text('Register and maintain the buses used by PlayPlace.',style:TextStyle(color:Color(0xFF64816D))),
     const SizedBox(height:18),Expanded(child:FutureBuilder<QuerySnapshot<Map<String,dynamic>>>(future:_busesFuture,builder:(context,snap){
      if(snap.hasError)return Center(child:Text('Could not load buses: '+snap.error.toString()));
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final docs=snap.data!.docs;final active=docs.where((d)=>d.data()['active']==true).length;
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Wrap(spacing:12,runSpacing:12,children:[_Metric(label:'Registered buses',value:docs.length.toString(),icon:Icons.directions_bus_outlined),_Metric(label:'Active buses',value:active.toString(),icon:Icons.check_circle_outline)]),
       const SizedBox(height:12),_PendingDrivers(key:ValueKey(_refreshVersion)),
       const SizedBox(height:12),_RecentArrivals(key:ValueKey('arrivals-$_refreshVersion'),buses:docs),
       const SizedBox(height:18),Row(children:[const Expanded(child:Text('Bus registry',style:TextStyle(fontSize:19,fontWeight:FontWeight.w700))),FilledButton.icon(onPressed:()=>showDialog(context:context,builder:(_)=>const _BusDialog()),icon:const Icon(Icons.add),label:const Text('Register bus'))]),
       const SizedBox(height:10),Expanded(child:docs.isEmpty?const Center(child:Text('No buses registered yet. Add your first bus.')):ListView.separated(
        itemCount:docs.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){
         final doc=docs[i],d=doc.data();final on=d['active']==true;
         return Container(decoration:BoxDecoration(color:Colors.white.withValues(alpha:.78),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF80B996).withValues(alpha:.3))),
          child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFE1F3E6),child:Icon(Icons.directions_bus,color:Color(0xFF328B55))),
           title:Text((d['busNumber']??'Bus').toString()+' · '+(d['registrationNumber']??'').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
           subtitle:Text((d['routeName']??'No route').toString()+' • '+(d['driverName']??'No driver assigned').toString()),
           trailing:Wrap(mainAxisSize:MainAxisSize.min,crossAxisAlignment:WrapCrossAlignment.center,children:[
            Chip(label:Text(on?'Active':'Inactive'),backgroundColor:on?const Color(0xFFDDF2E3):const Color(0xFFEEEEEE)),
            IconButton(tooltip:'Edit',icon:const Icon(Icons.edit_outlined),onPressed:()=>showDialog(context:context,builder:(_)=>_BusDialog(id:doc.id,data:d))),
            IconButton(tooltip:'Delete',icon:const Icon(Icons.delete_outline,color:Colors.redAccent),onPressed:()=>_delete(context,doc.id))])));
        }))]);
     }))
    ]))))));
 }
 Future<void>_delete(BuildContext context,String id)async{
  final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Delete this bus?'),content:const Text('This removes the bus record.'),actions:[
   TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]));
  if(yes==true)await FirebaseFirestore.instance.collection('buses').doc(id).delete();
 }
}
class _Metric extends StatelessWidget{
 const _Metric({required this.label,required this.value,required this.icon});final String label,value;final IconData icon;
 @override Widget build(BuildContext context)=>Container(width:220,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.8),borderRadius:BorderRadius.circular(18)),child:Row(children:[Icon(icon,color:const Color(0xFF328B55),size:28),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(color:Color(0xFF64816D)))])]));
}
class _BusDialog extends StatefulWidget{
 const _BusDialog({this.id,this.data});final String?id;final Map<String,dynamic>?data;
 @override State<_BusDialog>createState()=>_BusDialogState();
}
class _BusDialogState extends State<_BusDialog>{
 late final bus=TextEditingController(text:widget.data?['busNumber']??'');
 late final reg=TextEditingController(text:widget.data?['registrationNumber']??'');
 late final route=TextEditingController(text:widget.data?['routeName']??'');
 late final driver=TextEditingController(text:widget.data?['driverName']??'');
 late final phone=TextEditingController(text:widget.data?['driverPhone']??'');
 bool active=true,saving=false;
 @override void initState(){super.initState();active=widget.data?['active']!=false;}
 @override void dispose(){bus.dispose();reg.dispose();route.dispose();driver.dispose();phone.dispose();super.dispose();}
 Future<void>save()async{
  if(bus.text.trim().isEmpty||reg.text.trim().isEmpty)return;setState(()=>saving=true);
  final data=<String,dynamic>{'busNumber':bus.text.trim(),'registrationNumber':reg.text.trim().toUpperCase(),'routeName':route.text.trim(),'driverName':driver.text.trim(),'driverPhone':phone.text.trim(),'active':active,'updatedAt':FieldValue.serverTimestamp()};
  final ref=FirebaseFirestore.instance.collection('buses');
  if(widget.id==null){data['createdAt']=FieldValue.serverTimestamp();await ref.add(data);}else{await ref.doc(widget.id).update(data);}
  if(mounted)Navigator.pop(context);
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.id==null?'Register a bus':'Edit bus'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  TextField(controller:bus,decoration:const InputDecoration(labelText:'Bus number *')),TextField(controller:reg,decoration:const InputDecoration(labelText:'Registration number *')),
  TextField(controller:route,decoration:const InputDecoration(labelText:'Route / service name')),TextField(controller:driver,decoration:const InputDecoration(labelText:'Driver name')),
  TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Driver phone')),
  SwitchListTile(value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Bus is active'))]))),
  actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save'))]);
}
class _InviteDialog extends StatefulWidget{const _InviteDialog();@override State<_InviteDialog>createState()=>_InviteDialogState();}
class _InviteDialogState extends State<_InviteDialog>{
 final email=TextEditingController();bool saving=false;String?error;
 @override void dispose(){email.dispose();super.dispose();}
 Future<void>invite()async{
  final value=email.text.trim().toLowerCase();if(!value.contains('@')){setState(()=>error='Enter a valid email.');return;}setState(()=>saving=true);
  try{
   await FirebaseFirestore.instance.collection('adminInvites').doc(value).set({'email':value,'status':'pending','invitedBy':FirebaseAuth.instance.currentUser!.uid,'createdAt':FieldValue.serverTimestamp(),'expiresAt':Timestamp.fromDate(DateTime.now().add(const Duration(days:7)))});
   if(mounted){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Invitation created. Share the PlayPlace admin page URL with the invited person.')));}
  }on FirebaseException catch(e){if(mounted)setState(()=>error=e.message??'Could not invite admin.');}
  finally{if(mounted)setState(()=>saving=false);}
 }
 @override Widget build(BuildContext context)=>AlertDialog(title:const Text('Invite an administrator'),content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[
  const Text('The invited person must register using this exact email. Invitation expires after 7 days.'),
  TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email address')),
  if(error!=null)Text(error!,style:const TextStyle(color:Colors.red))])),
  actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:saving?null:invite,child:Text(saving?'Creating…':'Create invitation'))]);
}
class _PendingDrivers extends StatelessWidget{
 const _PendingDrivers({super.key});
 @override Widget build(BuildContext context){
  final requests=FirebaseFirestore.instance.collection('driverProfiles').where('status',isEqualTo:'pending');
  return FutureBuilder<QuerySnapshot<Map<String,dynamic>>>(future:requests.get(),builder:(context,snapshot){
   if(snapshot.hasError)return Text('Could not load driver requests: ${snapshot.error}');
   if(!snapshot.hasData)return const LinearProgressIndicator();
   final docs=snapshot.data!.docs;
   return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.72),borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Text('Driver approval requests (${docs.length})',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:17)),
     if(docs.isEmpty)const Padding(padding:EdgeInsets.only(top:8),child:Text('No pending driver requests.')),
     for(final doc in docs)ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Icon(Icons.person_outline)),
      title:Text((doc.data()['name']??'Driver').toString()),subtitle:Text('${doc.data()['email']??''} · Bus ${doc.data()['busNumber']??''}'),
      trailing:Wrap(mainAxisSize:MainAxisSize.min,children:[
       IconButton(tooltip:'Reject',onPressed:()=>doc.reference.update({'status':'rejected','reviewedAt':FieldValue.serverTimestamp()}),icon:const Icon(Icons.close,color:Colors.redAccent)),
       IconButton(tooltip:'Approve',onPressed:()=>doc.reference.update({'status':'approved','approvedAt':FieldValue.serverTimestamp(),'approvedBy':FirebaseAuth.instance.currentUser!.uid}),icon:const Icon(Icons.check_circle,color:Color(0xFF328B55))),
      ]))
    ]));
  });
 }
}

class _RecentArrivals extends StatelessWidget {
 const _RecentArrivals({super.key,required this.buses});
 final List<QueryDocumentSnapshot<Map<String,dynamic>>> buses;
 Future<List<Map<String,dynamic>>> _load() async {
  final items=<Map<String,dynamic>>[];
  for(final bus in buses){
   final snap=await bus.reference.collection('locationStatus').doc('latest').get();
   if(snap.exists){final data=snap.data()!;items.add({...data,'busNumber':bus.data()['busNumber']??'Bus'});}
  }
  items.sort((a,b){
   final at=a['reachedAt'];final bt=b['reachedAt'];
   final ad=at is Timestamp?at.toDate():DateTime.fromMillisecondsSinceEpoch(0);
   final bd=bt is Timestamp?bt.toDate():DateTime.fromMillisecondsSinceEpoch(0);
   return bd.compareTo(ad);
  });
  return items.take(8).toList();
 }
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(
  future:_load(),builder:(context,snapshot){
   if(snapshot.hasError)return Text('Could not load arrival updates: ${snapshot.error}');
   if(!snapshot.hasData)return const LinearProgressIndicator();
   final events=snapshot.data!;
   return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.72),borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     const Text('Recent stop arrivals',style:TextStyle(fontWeight:FontWeight.w700,fontSize:17)),
     if(events.isEmpty)const Padding(padding:EdgeInsets.only(top:8),child:Text('No arrival reports yet.')),
     for(final event in events)ListTile(dense:true,contentPadding:EdgeInsets.zero,
      leading:const Icon(Icons.location_on_outlined,color:Color(0xFF328B55)),
      title:Text('${event['busNumber']} · ${event['stopName']??'Stop'}'),
      subtitle:Text('${event['driverName']??'Driver'} · ${event['routeName']??''}'),
      trailing:Text(event['reachedAt'] is Timestamp?TimeOfDay.fromDateTime((event['reachedAt'] as Timestamp).toDate()).format(context):'Just now'),
     )
    ]));
  });
}
