import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class DriverAuthGate extends StatelessWidget {
  const DriverAuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, auth) {
      if (auth.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final user = auth.data;
      if (user == null) return const DriverSignInPage();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('driverProfiles').doc(user.uid).snapshots(),
        builder: (context, profile) {
          if (profile.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final data = profile.data?.data();
          if (data == null || data['status'] != 'approved') return _ApprovalPendingPage(status: data?['status']?.toString() ?? 'pending');
          return const Home();
        });
    });
}

class DriverSignInPage extends StatefulWidget {
  const DriverSignInPage({super.key});
  @override State<DriverSignInPage> createState() => _DriverSignInPageState();
}
class _DriverSignInPageState extends State<DriverSignInPage> {
  final bus = TextEditingController(), name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false;
  String? error;
  @override void dispose() { bus.dispose(); name.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    final busNumber = bus.text.trim(), mail = email.text.trim().toLowerCase(), pass = password.text;
    if (busNumber.isEmpty || mail.isEmpty || pass.length < 6 || (register && name.text.trim().isEmpty)) {
      setState(() => error = 'Enter Bus ID, email, password (at least 6 characters), and name when registering.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      if (register) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: mail, password: pass);
        try {
          final buses = await FirebaseFirestore.instance.collection('buses')
            .where('busNumber', isEqualTo: busNumber).where('active', isEqualTo: true).limit(1).get();
          if (buses.docs.isEmpty) throw Exception('Active Bus ID not found. Check with your admin.');
          final busDoc = buses.docs.first;
          await FirebaseFirestore.instance.collection('driverProfiles').doc(credential.user!.uid).set({
            'name': name.text.trim(), 'email': mail, 'busNumber': busNumber, 'busId': busDoc.id,
            'status': 'pending', 'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (error) {
          try { await credential.user?.delete(); } catch (_) { await FirebaseAuth.instance.signOut(); }
          rethrow;
        }
      } else {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: mail, password: pass);
        final buses = await FirebaseFirestore.instance.collection('buses')
          .where('busNumber', isEqualTo: busNumber).where('active', isEqualTo: true).limit(1).get();
        final profile = await FirebaseFirestore.instance.collection('driverProfiles').doc(credential.user!.uid).get();
        final data = profile.data();
        if (buses.docs.isEmpty || data == null || data['busNumber'] != busNumber || data['busId'] != buses.docs.first.id) {
          await FirebaseAuth.instance.signOut();
          throw Exception('This driver account is not assigned to that active Bus ID.');
        }
      }
    } on FirebaseAuthException catch (e) { setState(() => error = e.message ?? 'Authentication failed.'); }
    catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2FBF5), Color(0xFFE2F4E8), Color(0xFFD5EEDD)])),
      child: Center(child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Card(color: Colors.white.withValues(alpha: .82), margin: const EdgeInsets.all(24),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_bus, size: 52, color: Color(0xFF328B55)),
            const SizedBox(height: 12),
            Text(register ? 'Driver registration' : 'Driver sign in', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8), const Text('Use your Bus ID and personal driver account.', textAlign: TextAlign.center),
            const SizedBox(height: 18), TextField(controller: bus, decoration: const InputDecoration(labelText: 'Bus ID')),
            if (register) TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Driver email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16), FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait…' : register ? 'Register for admin approval' : 'Sign in')),
            TextButton(onPressed: busy ? null : () => setState(() { register = !register; error = null; }), child: Text(register ? 'Already registered? Sign in' : 'New driver? Register here')),
          ])),
        ))),
      ),
    ),
  );
}

class _ApprovalPendingPage extends StatelessWidget {
  const _ApprovalPendingPage({required this.status});
  final String status;
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.hourglass_top_rounded, size: 56, color: Color(0xFF328B55)),
    const SizedBox(height: 14), Text(status == 'rejected' ? 'Registration not approved' : 'Waiting for admin approval', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8), const Text('Your account can access shared bus routes after an administrator approves your request.', textAlign: TextAlign.center),
    const SizedBox(height: 18), OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
  ]))));
}
