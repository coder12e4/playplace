import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';
import 'admin_login_page.dart';
class AdminGate extends StatelessWidget {
 const AdminGate({super.key});
 @override Widget build(BuildContext context)=>StreamBuilder<User?>(
  stream:FirebaseAuth.instance.authStateChanges(),builder:(context,auth){
   if(auth.connectionState==ConnectionState.waiting)return const _Wait();
   final user=auth.data;if(user==null)return const AdminLoginPage();
   return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('admins').doc(user.uid).snapshots(),
    builder:(context,role){
     if(role.connectionState==ConnectionState.waiting)return const _Wait();
     if(role.data?.exists!=true||role.data?.data()?['active']!=true)return Scaffold(
      backgroundColor:const Color(0xFFEAF8EF),body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
       const Icon(Icons.lock_outline,size:48,color:Color(0xFF328B55)),
       const Text('Admin access required',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
       const Text('This account does not have an active admin role.'),
       FilledButton(onPressed:()=>FirebaseAuth.instance.signOut(),child:const Text('Sign out'))])));
     return const AdminDashboardPage();
    });
  });
}
class _Wait extends StatelessWidget{
 const _Wait();
 @override Widget build(BuildContext context)=>const Scaffold(backgroundColor:Color(0xFFEAF8EF),body:Center(child:CircularProgressIndicator(color:Color(0xFF328B55))));
}