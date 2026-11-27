import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bus_route_run_page.dart';
import 'driver_calendar_page.dart';
import 'package:flutter/material.dart';
import 'glass_card.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusStop {
  BusStop({
    required this.name,
    required this.point,
    this.arrivingAudio,
    this.arrivedAudio,
    this.arrivingRepeatCount = 1,
    this.arrivedRepeatCount = 1,
  });

  String name;
  LatLng point;
  String? arrivingAudio;
  String? arrivedAudio;
  int arrivingRepeatCount;
  int arrivedRepeatCount;

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': point.latitude,
        'lng': point.longitude,
        'arrivingAudio': arrivingAudio,
        'arrivedAudio': arrivedAudio,
        'arrivingRepeatCount': arrivingRepeatCount,
        'arrivedRepeatCount': arrivedRepeatCount,
      };

  factory BusStop.fromJson(Map<String, dynamic> json) => BusStop(
        name: json['name'] as String,
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        arrivingAudio: json['arrivingAudio'] as String?,
        arrivedAudio: json['arrivedAudio'] as String?,
        arrivingRepeatCount: (json['arrivingRepeatCount'] as num?)?.toInt() ?? 1,
        arrivedRepeatCount: (json['arrivedRepeatCount'] as num?)?.toInt() ?? 1,
      );
}

class BusRoute {
  BusRoute({
    required this.name,
    required this.start,
    required this.destination,
    required this.stops,
  });

  String name;
  LatLng start;
  LatLng destination;
  List<BusStop> stops;

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': [start.latitude, start.longitude],
        'destination': [destination.latitude, destination.longitude],
        'stops': stops.map((stop) => stop.toJson()).toList(),
      };

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final start = json['start'] as List;
    final destination = json['destination'] as List;
    return BusRoute(
      name: json['name'] as String,
      start: LatLng((start[0] as num).toDouble(), (start[1] as num).toDouble()),
      destination: LatLng(
        (destination[0] as num).toDouble(),
        (destination[1] as num).toDouble(),
      ),
      stops: (json['stops'] as List)
          .map((item) => BusStop.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum _MapPick { start, destination, stop }

class BusRoutesPage extends StatefulWidget {
  const BusRoutesPage({super.key});

  @override
  State<BusRoutesPage> createState() => _BusRoutesPageState();
}

class _BusRoutesPageState extends State<BusRoutesPage> {
  final _routeName = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final List<BusStop> _stops = [];
  final List<BusRoute> _savedRoutes = [];
  final List<String> _savedRouteIds = [];
  String? _busId;
  LatLng? _start;
  LatLng? _destination;
  LatLng _mapCenter = const LatLng(10.0, 76.3);
  _MapPick _pick = _MapPick.start;
  String? _recordingKey;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _centerOnCurrentLocation();
  }

  @override
  void dispose() {
    _routeName.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await FirebaseFirestore.instance.collection('driverProfiles').doc(uid).get();
      final data = profile.data();
      if (data == null || data['status'] != 'approved' || data['busId'] == null) return;
      final busId = data['busId'] as String;
      final snapshot = await FirebaseFirestore.instance.collection('buses').doc(busId).collection('routes').orderBy('updatedAt', descending: true).get();
      final prefs = await SharedPreferences.getInstance();
      final loaded = <BusRoute>[]; final ids = <String>[];
      for (final doc in snapshot.docs) {
        try {
          final route = BusRoute.fromJson(doc.data());
          final local = prefs.getString('playplace_local_audio_${doc.id}');
          if (local != null) {
            final audio = jsonDecode(local) as List<dynamic>;
            for (var i = 0; i < route.stops.length && i < audio.length; i++) {
              final item = audio[i] as Map<String, dynamic>;
              route.stops[i].arrivingAudio = item['arrivingAudio'] as String?;
              route.stops[i].arrivedAudio = item['arrivedAudio'] as String?;
            }
          }
          loaded.add(route); ids.add(doc.id);
        } catch (error) { debugPrint('Skipping invalid shared route ${doc.id}: $error'); }
      }
      if (mounted) setState(() { _busId = busId; _savedRoutes..clear()..addAll(loaded); _savedRouteIds..clear()..addAll(ids); });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load bus routes: $error')));
    }
  }
  Future<void> _centerOnCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _mapCenter = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {
      // The driver can still select route points manually on the map.
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      switch (_pick) {
        case _MapPick.start:
          _start = point;
          break;
        case _MapPick.destination:
          _destination = point;
          break;
        case _MapPick.stop:
          _stops.add(BusStop(
            name: 'Stop ${_stops.length + 1}',
            point: point,
          ));
          break;
      }
    });
  }

  Future<void> _renameStop(int index) async {
    final controller = TextEditingController(text: _stops[index].name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this stop'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Town Hall'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _stops[index].name = name);
    }
  }

  Future<void> _recordVoice(int stopIndex, bool arriving) async {
    final key = '$stopIndex-${arriving ? 'arriving' : 'arrived'}';
    if (_recordingKey == key) {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          if (path != null) {
            if (arriving) {
              _stops[stopIndex].arrivingAudio = path;
            } else {
              _stops[stopIndex].arrivedAudio = path;
            }
          }
          _recordingKey = null;
        });
      }
      return;
    }
    if (_recordingKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop the current recording first.')),
      );
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/bus_stop_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    if (mounted) setState(() => _recordingKey = key);
  }

  Future<void> _preview(String? path) async {
    if (path == null) return;
    if (path.startsWith('https://')) { await _player.play(UrlSource(path)); }
    else if (File(path).existsSync()) { await _player.play(DeviceFileSource(path)); }
  }

  Future<void> _saveRoute() async {
    if (_saving) return;
    final name = _routeName.text.trim();
    if (name.isEmpty || _start == null || _destination == null || _stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a route name, start, destination and at least one stop.'))); return;
    }
    if (_recordingKey != null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stop the active recording before saving.'))); return; }
    final incomplete = _stops.indexWhere((stop) => stop.arrivingAudio == null || stop.arrivedAudio == null);
    if (incomplete != -1) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record both arriving and arrived voices for ${_stops[incomplete].name}.'))); return; }
    final busId = _busId;
    if (busId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your approved bus account is not ready. Sign in again.'))); return; }
    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('buses').doc(busId).collection('routes').doc();
      final audio = _stops.map((stop) => {'arrivingAudio': stop.arrivingAudio, 'arrivedAudio': stop.arrivedAudio}).toList();
      final sharedStops = _stops.map((stop) => BusStop(name: stop.name, point: stop.point, arrivingRepeatCount: stop.arrivingRepeatCount, arrivedRepeatCount: stop.arrivedRepeatCount)).toList();
      final route = BusRoute(name: name, start: _start!, destination: _destination!, stops: sharedStops);
      await ref.set({...route.toJson(), 'createdBy': FirebaseAuth.instance.currentUser!.uid, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playplace_local_audio_${ref.id}', jsonEncode(audio));
      if (mounted) setState(() { _routeName.clear(); _start = null; _destination = null; _stops.clear(); _pick = _MapPick.start; _saving = false; });
      await _loadRoutes();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route shared. Voice recordings stay on this device only.')));
    } catch (error) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share route: $error'))); }
    }
  }
  Future<void> _deleteRoute(int index) async {
    final busId = _busId;
    if (busId == null || index >= _savedRouteIds.length) return;
    try {
      await FirebaseFirestore.instance.collection('buses').doc(busId).collection('routes').doc(_savedRouteIds[index]).delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('playplace_local_audio_${_savedRouteIds[index]}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared route deleted for this bus.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete route: $error')));
    }
  }

  Widget _pickButton(String label, _MapPick value, IconData icon) {
    return ChoiceChip(
      selected: _pick == value,
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onSelected: (_) => setState(() => _pick = value),
    );
  }

  Widget _voiceControls(int index, bool arriving) {
    final stop = _stops[index];
    final path = arriving ? stop.arrivingAudio : stop.arrivedAudio;
    final key = '$index-${arriving ? 'arriving' : 'arrived'}';
    final active = _recordingKey == key;
    final repeatCount = arriving ? stop.arrivingRepeatCount : stop.arrivedRepeatCount;
    return Row(
      children: [
        Expanded(
          child: Text(
            arriving ? 'Arriving voice' : 'Arrived voice',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        DropdownButton<int>(
          value: repeatCount.clamp(1, 10).toInt(),
          underline: const SizedBox.shrink(),
          isDense: true,
          items: List.generate(10, (i) => i + 1)
              .map((count) => DropdownMenuItem(value: count, child: Text('×$count')))
              .toList(),
          onChanged: (count) {
            if (count == null) return;
            setState(() {
              if (arriving) {
                stop.arrivingRepeatCount = count;
              } else {
                stop.arrivedRepeatCount = count;
              }
            });
          },
        ),
        if (path != null && !active)
          IconButton(
            tooltip: 'Preview recording',
            visualDensity: VisualDensity.compact,
            onPressed: () => _preview(path),
            icon: const Icon(Icons.play_circle_outline),
          ),
        IconButton.filledTonal(
          tooltip: active ? 'Stop recording' : 'Record voice',
          visualDensity: VisualDensity.compact,
          onPressed: () => _recordVoice(index, arriving),
          icon: Icon(active ? Icons.stop : Icons.mic),
          style: IconButton.styleFrom(
            foregroundColor: active ? Colors.white : null,
            backgroundColor: active ? Colors.red : null,
          ),
        ),
        if (path != null && !active)
          const Icon(Icons.check_circle, color: const Color(0xFF328B55), size: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      if (_start != null) _start!,
      ..._stops.map((stop) => stop.point),
      if (_destination != null) _destination!,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared bus routes'),
        actions: [
          IconButton(tooltip: 'Refresh shared routes', icon: const Icon(Icons.refresh), onPressed: _loadRoutes),
          IconButton(
            tooltip: 'Driver calendar and performance',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverCalendarPage()),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2FBF5), Color(0xFFE2F4E8), Color(0xFFD5EEDD)],
          ),
        ),
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _routeName,
            decoration: const InputDecoration(
              labelText: 'Route name',
              hintText: 'e.g. Town – Railway Station',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_bus),
            ),
          ),
          const SizedBox(height: 12),
          Text('Choose what to place, then tap the map',
              style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              _pickButton('Start point', _MapPick.start, Icons.trip_origin),
              _pickButton('Add stop', _MapPick.stop, Icons.add_location_alt),
              _pickButton('Destination', _MapPick.destination, Icons.flag),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: 12,
                  onTap: (_, point) => _onMapTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.playplace',
                  ),
                  if (points.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: points, strokeWidth: 4, color: const Color(0xFF4EAA70)),
                    ]),
                  MarkerLayer(
                    markers: [
                      if (_start != null)
                        Marker(
                          point: _start!,
                          width: 42,
                          height: 42,
                          child: const Icon(Icons.trip_origin, color: Colors.green, size: 34),
                        ),
                      for (var i = 0; i < _stops.length; i++)
                        Marker(
                          point: _stops[i].point,
                          width: 42,
                          height: 42,
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFF4EAA70),
                            child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 42,
                          height: 42,
                          child: const Icon(Icons.flag, color: const Color(0xFFCF665E), size: 34),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: ${_pick == _MapPick.start ? 'start point' : _pick == _MapPick.destination ? 'destination' : 'intermediate stop'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Intermediate stops (${_stops.length})',
              style: Theme.of(context).textTheme.titleMedium),
          if (_stops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Choose “Add stop” and tap each stop location on the map.'),
            ),
          for (var i = 0; i < _stops.length; i++)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          child: Text('${i + 1}'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _renameStop(i),
                            child: Text(
                              _stops[i].name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename stop',
                          onPressed: () => _renameStop(i),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remove stop',
                          onPressed: () => setState(() => _stops.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    _voiceControls(i, true),
                    _voiceControls(i, false),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _saveRoute,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Saving…' : 'Save bus route'),
          ),
          const SizedBox(height: 24),
          Text('Saved routes (${_savedRoutes.length})',
              style: Theme.of(context).textTheme.titleLarge),
          if (_savedRoutes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Your registered routes will appear here.'),
            ),
          for (var i = 0; i < _savedRoutes.length; i++)
            GlassCard(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.directions_bus)),
                title: Text(_savedRoutes[i].name),
                subtitle: Text(
                  '${_savedRoutes[i].stops.length} stops · '
                  '${_savedRoutes[i].stops.where((s) => s.arrivingAudio != null).length} arriving clips · '
                  '${_savedRoutes[i].stops.where((s) => s.arrivedAudio != null).length} arrived clips',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Start GPS announcements',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusRouteRunPage(route: _savedRoutes[i]),
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Delete route',
                      onPressed: () => _deleteRoute(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
