import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class SuperAdminController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final packages = <QueryDocumentSnapshot<Map<String, dynamic>>>[].obs;
  final admins = <QueryDocumentSnapshot<Map<String, dynamic>>>[].obs;
  final invitations = <QueryDocumentSnapshot<Map<String, dynamic>>>[].obs;
  final isLoading = false.obs;
  final loadError = ''.obs;

  @override
  void onInit() { super.onInit(); refreshAll(); }

  Future<void> refreshAll() async {
    isLoading.value = true;
    loadError.value = '';
    try {
      final results = await Future.wait([
        _db.collection('subscriptionPackages').orderBy('createdAt', descending: true).get(),
        _db.collection('admins').get(),
        _db.collection('adminInvites').where('status', isEqualTo: 'pending').get(),
      ]);
      packages.assignAll(results[0].docs);
      admins.assignAll(results[1].docs);
      invitations.assignAll(results[2].docs);
    } catch (e) {
      loadError.value = e.toString();
      _error('Could not load Super Admin data', e);
    } finally { isLoading.value = false; }
  }

  Future<bool> savePackage({String? id, required String name, required double price,
    required int durationDays, required int maxBuses, required List<String> features,
    required bool active}) async {
    try {
      final data = {'name': name.trim(), 'price': price, 'durationDays': durationDays,
        'maxBuses': maxBuses, 'features': features, 'active': active,
        'updatedAt': FieldValue.serverTimestamp()};
      final col = _db.collection('subscriptionPackages');
      if (id == null) {
        await col.add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else { await col.doc(id).update(data); }
      await refreshAll();
      return true;
    } catch (e) { _error('Could not save package', e); return false; }
  }

  Future<void> togglePackage(QueryDocumentSnapshot<Map<String, dynamic>> item) async {
    try {
      await item.reference.update({'active': item.data()['active'] != true,
        'updatedAt': FieldValue.serverTimestamp()});
      await refreshAll();
    } catch (e) { _error('Could not update package', e); }
  }

  Future<void> deletePackage(QueryDocumentSnapshot<Map<String, dynamic>> item) async {
    try { await item.reference.delete(); await refreshAll(); }
    catch (e) { _error('Could not delete package', e); }
  }

  Future<void> approveAdmin(QueryDocumentSnapshot<Map<String, dynamic>> item, bool approve) async {
    try {
      await item.reference.update({'active': approve,
        'approvalStatus': approve ? 'approved' : 'rejected',
        approve ? 'approvedAt' : 'rejectedAt': FieldValue.serverTimestamp()});
      await refreshAll();
    } catch (e) { _error('Could not update administrator', e); }
  }

  Future<void> toggleAdmin(QueryDocumentSnapshot<Map<String, dynamic>> item) async {
    try { await item.reference.update({'active': item.data()['active'] != true}); await refreshAll(); }
    catch (e) { _error('Could not change administrator status', e); }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> activePackages() async {
    final result = await _db.collection('subscriptionPackages').where('active', isEqualTo: true).get();
    return result.docs;
  }

  Future<bool> assignPackage(QueryDocumentSnapshot<Map<String, dynamic>> admin,
      QueryDocumentSnapshot<Map<String, dynamic>> package) async {
    try {
      final data = package.data();
      final days = (data['durationDays'] as num?)?.toInt() ?? 30;
      final now = DateTime.now();
      await admin.reference.update({'subscription': {'packageId': package.id,
        'packageName': data['name'], 'price': data['price'], 'maxBuses': data['maxBuses'],
        'features': data['features'] ?? [], 'startedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(Duration(days: days))), 'status': 'active'}});
      await refreshAll();
      return true;
    } catch (e) { _error('Could not assign subscription', e); return false; }
  }

  Future<void> deleteInvitation(QueryDocumentSnapshot<Map<String, dynamic>> item) async {
    try { await item.reference.delete(); await refreshAll(); }
    catch (e) { _error('Could not delete invitation', e); }
  }

  Future<void> signOut() async {
    try { await FirebaseAuth.instance.signOut(); Get.offAllNamed('/admin'); }
    catch (e) { _error('Could not sign out', e); }
  }

  void _error(String title, Object error) => Get.snackbar(title, error.toString(),
    snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFFFFE9E9),
    colorText: const Color(0xFF7A2424), margin: const EdgeInsets.all(12));
}
