import 'package:flutter/material.dart';
import 'glass_card.dart';
import 'driver_performance.dart';

class DriverCalendarPage extends StatefulWidget {
 const DriverCalendarPage({super.key});
 @override State<DriverCalendarPage> createState()=>_DriverCalendarPageState();
}
class _DriverCalendarPageState extends State<DriverCalendarPage> {
 DateTime _month=DateTime(DateTime.now().year,DateTime.now().month),_selected=DateTime.now();
 List<DriverTripRecord> _records=[];bool _loading=true;
 @override void initState(){super.initState();_load();}
 Future<void> _load() async {final r=await DriverPerformanceStore.load();if(mounted)setState(()=>_records=r);}
 List<DriverTripRecord> _day(DateTime d)=>_records.where((r)=>r.startedAt.year==d.year&&r.startedAt.month==d.month&&r.startedAt.day==d.day).toList();
 @override Widget build(BuildContext context){
 final count=DateUtils.getDaysInMonth(_month.year,_month.month),offset=DateTime(_month.year,_month.month,1).weekday-1;
 final selected=_day(_selected),monthly=_records.where((r)=>r.startedAt.year==_month.year&&r.startedAt.month==_month.month).toList();
 final km=monthly.fold<double>(0,(v,r)=>v+r.distanceMeters)/1000;
 final speed=monthly.isEmpty?0.0:monthly.fold<double>(0,(v,r)=>v+r.averageSpeedKmh)/monthly.length;
 final accuracy=monthly.isEmpty?0.0:monthly.fold<double>(0,(v,r)=>v+r.averageAccuracyMeters)/monthly.length;
 return Scaffold(appBar:AppBar(title:const Text('Driver calendar & performance')),body:DecoratedBox(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFF2FBF5),Color(0xFFE2F4E8),Color(0xFFD5EEDD)])),child:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
 GlassCard(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
 Row(children:[IconButton(onPressed:()=>setState(()=>_month=DateTime(_month.year,_month.month-1)),icon:const Icon(Icons.chevron_left)),Expanded(child:Text(_month.year.toString()+'-'+_month.month.toString().padLeft(2,'0'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:()=>setState(()=>_month=DateTime(_month.year,_month.month+1)),icon:const Icon(Icons.chevron_right))]),
 const Row(children:[for(final d in ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'])Expanded(child:Center(child:Text(d,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600))))]),
 const SizedBox(height:8),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:offset+count,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,mainAxisSpacing:5,crossAxisSpacing:5),itemBuilder:(c,i){if(i<offset)return const SizedBox.shrink();final day=i-offset+1,date=DateTime(_month.year,_month.month,day),has=_day(date).isNotEmpty,sel=DateUtils.isSameDay(date,_selected);return InkWell(onTap:()=>setState(()=>_selected=date),child:Container(decoration:BoxDecoration(color:sel?const Color(0xFF4EAA70):has?const Color(0xFFBDE5C9):Colors.white.withOpacity(.55),borderRadius:BorderRadius.circular(10)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(day.toString(),style:TextStyle(color:sel?Colors.white:const Color(0xFF17452D),fontWeight:FontWeight.w600)),if(has)Container(width:5,height:5,margin:const EdgeInsets.only(top:3),decoration:BoxDecoration(color:sel?Colors.white:const Color(0xFF328B55),shape:BoxShape.circle))])));}),
 const SizedBox(height:8),const Text('Green dots mark days with recorded trips.',style:TextStyle(fontSize:12,color:Color(0xFF62816D))),
 ]))),
 const SizedBox(height:14),Text('Monthly overview',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),
 Row(children:[_metric('Trips',monthly.length.toString(),Icons.route),const SizedBox(width:8),_metric('Distance',km.toStringAsFixed(1)+' km',Icons.straighten)]),
 const SizedBox(height:8),Row(children:[_metric('Avg speed',speed.toStringAsFixed(1)+' km/h',Icons.speed),const SizedBox(width:8),_metric('GPS accuracy',monthly.isEmpty?'—':'±'+accuracy.toStringAsFixed(0)+' m',Icons.gps_fixed)]),
 const SizedBox(height:18),Text('Daily average speed',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),GlassCard(child:Padding(padding:const EdgeInsets.all(14),child:_graph(monthly))),
 const SizedBox(height:18),Text('Trips on '+_selected.day.toString().padLeft(2,'0')+'/'+_selected.month.toString().padLeft(2,'0')+'/'+_selected.year.toString(),style:Theme.of(context).textTheme.titleMedium),
 if(selected.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('No completed route sessions on this day.'))
 else for(final r in selected)Padding(padding:const EdgeInsets.only(top:8),child:GlassCard(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text(r.routeName,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),
 Wrap(spacing:14,runSpacing:8,children:[_detail(Icons.timer,_duration(r.durationSeconds)),_detail(Icons.route,(r.distanceMeters/1000).toStringAsFixed(2)+' km'),_detail(Icons.speed,r.averageSpeedKmh.toStringAsFixed(1)+' km/h'),_detail(Icons.gps_fixed,'±'+r.averageAccuracyMeters.toStringAsFixed(0)+' m'),_detail(Icons.place,r.stopsCompleted.toString()+' stops')]),
 const SizedBox(height:5),Text(TimeOfDay.fromDateTime(r.startedAt).format(context)+' – '+TimeOfDay.fromDateTime(r.endedAt).format(context),style:const TextStyle(fontSize:12,color:Color(0xFF62816D))),
 ]))))),
 ])));
 }
 Widget _metric(String l,String v,IconData i)=>Expanded(child:GlassCard(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i,color:const Color(0xFF328B55)),const SizedBox(height:7),Text(v,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),Text(l,style:const TextStyle(fontSize:11,color:Color(0xFF62816D)))]))));
 Widget _detail(IconData i,String v)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(i,size:15,color:const Color(0xFF328B55)),const SizedBox(width:4),Text(v,style:const TextStyle(fontSize:12))]);
 Widget _graph(List<DriverTripRecord> records){final map=<int,List<double>>{};for(final r in records){map.putIfAbsent(r.startedAt.day,()=>[]).add(r.averageSpeedKmh);}if(map.isEmpty)return const Padding(padding:EdgeInsets.all(12),child:Text('Complete a route to see the daily speed graph.'));final max=map.values.expand((x)=>x).fold<double>(1,(a,b)=>a>b?a:b);final days=map.keys.toList()..sort();return SizedBox(height:150,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[for(final d in days)Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[Text((map[d]!.reduce((a,b)=>a+b)/map[d]!.length).toStringAsFixed(0),style:const TextStyle(fontSize:9)),const SizedBox(height:3),Container(height:95*((map[d]!.reduce((a,b)=>a+b)/map[d]!.length)/max).clamp(.06,1),decoration:BoxDecoration(color:const Color(0xFF67B982),borderRadius:BorderRadius.circular(5))),const SizedBox(height:4),Text(d.toString(),style:const TextStyle(fontSize:9))])))]));}
 String _duration(int s){final h=s~/3600,m=(s%3600)~/60;return h>0?h.toString()+'h '+m.toString()+'m':m.toString()+'m '+(s%60).toString()+'s';}
}
