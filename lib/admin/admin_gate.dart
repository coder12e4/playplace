import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';
import 'admin_login_page.dart';
import 'super_admin_dashboard_page.dart';

class AdminGate extends StatelessWidget {
 const AdminGate({super.key});
 @override Widget build(BuildContext context) {
  final user=FirebaseAuth.instance.currentUser;
  if(user==null)return const AdminLoginPage();
  return FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
   future:FirebaseFirestore.instance.collection('appConfig').doc('superAdmin').get(),
   builder:(context,owner){
    if(owner.connectionState==ConnectionState.waiting)return const Scaffold(backgroundColor:Color(0xFFEAF8EF),body:Center(child:CircularProgressIndicator(color:Color(0xFF328B55))));
    if(owner.data?.exists==true && owner.data?.data()?['uid']==user.uid)return const SuperAdminDashboardPage();
    return FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
     future:FirebaseFirestore.instance.collection('admins').doc(user.uid).get(),
     builder:(context,role){
      if(role.connectionState==ConnectionState.waiting)return const Scaffold(backgroundColor:Color(0xFFEAF8EF),body:Center(child:CircularProgressIndicator(color:Color(0xFF328B55))));
      if(role.data?.exists!=true||role.data?.data()?['active']!=true)return Scaffold(
       backgroundColor:const Color(0xFFEAF8EF),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.lock_outline,size:48,color:Color(0xFF328B55)),
        const Text('Admin access required',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const Text('This account does not have an active admin role.'),
        FilledButton(onPressed:()async{await FirebaseAuth.instance.signOut();if(context.mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const AdminGate()),(_)=>false);},child:const Text('Sign out'))
       ])));
      return const AdminDashboardPage();
     });
   });
 }
}
