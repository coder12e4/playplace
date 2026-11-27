import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_gate.dart';
class AdminLoginPage extends StatefulWidget{
 const AdminLoginPage({super.key});
 @override State<AdminLoginPage>createState()=>_AdminLoginPageState();
}
class _AdminLoginPageState extends State<AdminLoginPage>{
 final email=TextEditingController(),password=TextEditingController();
 bool signup=false,busy=false,hide=true;String?error;
 @override void dispose(){email.dispose();password.dispose();super.dispose();}
 Future<void>submit()async{
  if(busy)return;setState(() { busy=true; error=null; });
  try{
   final mail=email.text.trim().toLowerCase();
   if(!mail.contains('@')||password.text.length<6)throw FirebaseAuthException(code:'invalid-input',message:'Enter a valid email and a password of at least 6 characters.');
   if(!signup){await FirebaseAuth.instance.signInWithEmailAndPassword(email:mail,password:password.text);}
   else{
    final user=(await FirebaseAuth.instance.createUserWithEmailAndPassword(email:mail,password:password.text)).user!;
    final inviteRef=FirebaseFirestore.instance.collection('adminInvites').doc(mail);
    final invite=await inviteRef.get();
    if(!invite.exists||invite.data()?['status']!='pending'){
     await FirebaseAuth.instance.signOut();
     throw FirebaseAuthException(code:'no-invite',message:'No pending invitation exists for this email. Ask an existing admin to invite you.');
    }
    await inviteRef.update({'status':'accepted','uid':user.uid,'acceptedAt':FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('admins').doc(user.uid).set({'email':mail,'active':true,'source':'invitation','createdAt':FieldValue.serverTimestamp()});
   }
   if(mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const AdminGate()),(_)=>false);
  }on FirebaseAuthException catch(e){if(mounted)setState(()=>error=e.message??e.code);}
   on FirebaseException catch(e){if(mounted)setState(()=>error=e.message??'A Firebase request failed.');}
   catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(body:Container(
  decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFF4FCF6),Color(0xFFE3F4E8),Color(0xFFD5EEDD)])),
  child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:450),
   child:Container(padding:const EdgeInsets.all(30),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.78),borderRadius:BorderRadius.circular(28),border:Border.all(color:const Color(0xFF80B996).withValues(alpha:.35)),boxShadow:[BoxShadow(color:const Color(0xFF2E6C45).withValues(alpha:.08),blurRadius:30,offset:const Offset(0,14))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     const CircleAvatar(radius:30,backgroundColor:Color(0xFF4EAA70),child:Icon(Icons.admin_panel_settings_outlined,color:Colors.white,size:32)),
     const SizedBox(height:18),const Text('PlayPlace Admin',textAlign:TextAlign.center,style:TextStyle(fontSize:27,fontWeight:FontWeight.w800,color:Color(0xFF17452D))),
     const SizedBox(height:6),Text(signup?'Create your invited administrator account':'Sign in to manage buses and administrators',textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFF64816D))),
     const SizedBox(height:24),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Admin email',prefixIcon:Icon(Icons.email_outlined))),
     const SizedBox(height:12),TextField(controller:password,obscureText:hide,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility_outlined:Icons.visibility_off_outlined))),onSubmitted:(_)=>submit()),
     if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red))),
     const SizedBox(height:18),FilledButton(onPressed:busy?null:submit,child:Padding(padding:const EdgeInsets.symmetric(vertical:12),child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):Text(signup?'Create admin account':'Sign in'))),
     TextButton(onPressed:busy?null:()=>setState(() { signup=!signup; error=null; }),child:Text(signup?'Already registered? Sign in':'Have an invitation? Create account')),
     const Text('Admin accounts can only be created with an invitation from an existing administrator.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Color(0xFF789080)))
    ])))))));
}