import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DriverTripRecord {
 const DriverTripRecord({required this.id,required this.routeName,required this.startedAt,required this.endedAt,required this.durationSeconds,required this.distanceMeters,required this.averageSpeedKmh,required this.averageAccuracyMeters,required this.stopsCompleted});
 final String id,routeName; final DateTime startedAt,endedAt; final int durationSeconds,stopsCompleted; final double distanceMeters,averageSpeedKmh,averageAccuracyMeters;
 Map<String,dynamic> toJson()=>{'id':id,'routeName':routeName,'startedAt':startedAt.toIso8601String(),'endedAt':endedAt.toIso8601String(),'durationSeconds':durationSeconds,'distanceMeters':distanceMeters,'averageSpeedKmh':averageSpeedKmh,'averageAccuracyMeters':averageAccuracyMeters,'stopsCompleted':stopsCompleted};
 factory DriverTripRecord.fromJson(Map<String,dynamic> j)=>DriverTripRecord(id:j['id'] as String,routeName:j['routeName'] as String,startedAt:DateTime.parse(j['startedAt'] as String),endedAt:DateTime.parse(j['endedAt'] as String),durationSeconds:(j['durationSeconds'] as num).toInt(),distanceMeters:(j['distanceMeters'] as num).toDouble(),averageSpeedKmh:(j['averageSpeedKmh'] as num).toDouble(),averageAccuracyMeters:(j['averageAccuracyMeters'] as num).toDouble(),stopsCompleted:(j['stopsCompleted'] as num).toInt());
}
class DriverPerformanceStore {
 static const _key='playplace_driver_trip_records_v1';
 static Future<List<DriverTripRecord>> load() async {final p=await SharedPreferences.getInstance();final out=<DriverTripRecord>[];for(final s in p.getStringList(_key)??<String>[]){try{out.add(DriverTripRecord.fromJson(jsonDecode(s) as Map<String,dynamic>));}catch(_){}}out.sort((a,b)=>b.startedAt.compareTo(a.startedAt));return out;}
 static Future<void> save(DriverTripRecord r) async {final all=await load();all.removeWhere((x)=>x.id==r.id);all.add(r);all.sort((a,b)=>b.startedAt.compareTo(a.startedAt));final p=await SharedPreferences.getInstance();await p.setStringList(_key,all.map((x)=>jsonEncode(x.toJson())).toList());}
}
