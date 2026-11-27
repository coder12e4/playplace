import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverTripRecord {
 const DriverTripRecord({required this.id,required this.routeName,required this.startedAt,required this.endedAt,required this.durationSeconds,required this.distanceMeters,required this.averageSpeedKmh,required this.averageAccuracyMeters,required this.stopsCompleted});
 final String id,routeName; final DateTime startedAt,endedAt; final int durationSeconds,stopsCompleted; final double distanceMeters,averageSpeedKmh,averageAccuracyMeters;
 Map<String,dynamic> toJson()=>{'id':id,'routeName':routeName,'startedAt':startedAt.toIso8601String(),'endedAt':endedAt.toIso8601String(),'durationSeconds':durationSeconds,'distanceMeters':distanceMeters,'averageSpeedKmh':averageSpeedKmh,'averageAccuracyMeters':averageAccuracyMeters,'stopsCompleted':stopsCompleted};
 factory DriverTripRecord.fromJson(Map<String,dynamic> j)=>DriverTripRecord(id:j['id'] as String,routeName:j['routeName'] as String,startedAt:DateTime.parse(j['startedAt'] as String),endedAt:DateTime.parse(j['endedAt'] as String),durationSeconds:(j['durationSeconds'] as num).toInt(),distanceMeters:(j['distanceMeters'] as num).toDouble(),averageSpeedKmh:(j['averageSpeedKmh'] as num).toDouble(),averageAccuracyMeters:(j['averageAccuracyMeters'] as num).toDouble(),stopsCompleted:(j['stopsCompleted'] as num).toInt());
}
class DriverPerformanceStore {
 static CollectionReference<Map<String,dynamic>> get _records {
  final uid=FirebaseAuth.instance.currentUser?.uid;
  if(uid==null) throw StateError('A signed-in driver is required to access performance records.');
  return FirebaseFirestore.instance.collection('driverPerformance').doc(uid).collection('records');
 }
 static Future<List<DriverTripRecord>> load() async {
  final snapshot=await _records.orderBy('startedAt',descending:true).get();
  return snapshot.docs.map((doc)=>DriverTripRecord.fromJson({...doc.data(),'id':doc.id})).toList();
 }
 static Future<void> save(DriverTripRecord r) async {
  await _records.doc(r.id).set(r.toJson());
 }
}
