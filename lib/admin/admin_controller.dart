import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class AdminController extends GetxController {
  final buses = <QueryDocumentSnapshot<Map<String, dynamic>>>[].obs;
  final isLoading = false.obs;
  final error = ''.obs;
  Timer? _poller;

  @override
  void onInit() {
    super.onInit();
    refreshBuses();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => refreshBuses());
  }

  Future<void> refreshBuses() async {
    if (isLoading.value) return;
    isLoading.value = true;
    error.value = '';
    try {
      final result = await FirebaseFirestore.instance.collection('buses')
          .orderBy('createdAt', descending: true).get();
      buses.assignAll(result.docs);
    } catch (e) {
      error.value = 'Could not load buses: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveBus({String? id, required String busNumber,
    required String registrationNumber, required String routeName,
    required String driverName, required String driverPhone,
    required bool active}) async {
    final data = <String, dynamic>{
      'busNumber': busNumber.trim(),
      'registrationNumber': registrationNumber.trim().toUpperCase(),
      'routeName': routeName.trim(), 'driverName': driverName.trim(),
      'driverPhone': driverPhone.trim(), 'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final ref = FirebaseFirestore.instance.collection('buses');
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.add(data);
    } else {
      await ref.doc(id).update(data);
    }
    await refreshBuses();
  }

  Future<void> deleteBus(String id) async {
    await FirebaseFirestore.instance.collection('buses').doc(id).delete();
    await refreshBuses();
  }

  Future<void> inviteAdmin(String email) async {
    final value = email.trim().toLowerCase();
    if (!value.contains('@')) throw ArgumentError('Enter a valid email.');
    await FirebaseFirestore.instance.collection('adminInvites').doc(value).set({
      'email': value, 'status': 'pending',
      'invitedBy': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });
  }

  Future<void> reviewDriver(QueryDocumentSnapshot<Map<String, dynamic>> driver,
      {required bool approve}) async {
    final data = <String, dynamic>{
      'status': approve ? 'approved' : 'rejected',
      approve ? 'approvedAt' : 'reviewedAt': FieldValue.serverTimestamp(),
    };
    if (approve) data['approvedBy'] = FirebaseAuth.instance.currentUser!.uid;
    await driver.reference.update(data);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed('/admin');
  }

  @override
  void onClose() {
    _poller?.cancel();
    super.onClose();
  }
}