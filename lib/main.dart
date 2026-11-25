// ============================================================
// Voice Trigger – record voices, pin them on a map, and have
// them play (through your connected Bluetooth speaker) when you
// arrive at that spot.
//
// SETUP
// 1) flutter create voice_trigger && cd voice_trigger
// 2) flutter pub add record audioplayers geolocator flutter_map \
//      latlong2 path_provider shared_preferences
// 3) Replace lib/main.dart with this file.
// 4) Android: android/app/src/main/AndroidManifest.xml (inside <manifest>)
//      <uses-permission android:name="android.permission.INTERNET"/>
//      <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//      <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//      <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//      <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
//      <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
//      <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
//      <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//      <uses-permission android:name="android.permission.WAKE_LOCK"/>
//    and in android/app/build.gradle set minSdkVersion 23 (or higher).
// 5) iOS: ios/Runner/Info.plist
//      NSLocationWhenInUseUsageDescription
//      NSLocationAlwaysAndWhenInUseUsageDescription
//      NSMicrophoneUsageDescription
//      UIBackgroundModes -> [location, audio]
//
// Bluetooth: no code needed. Audio plays through whatever output the
// phone is using, so connect your speaker first and it will play there.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';



void main() => runApp(const MaterialApp(home: Home()));

// ---------- Model ----------
class VoiceTrigger {
  VoiceTrigger(this.name, this.path, this.point, this.radius,
      {this.approachPath, this.approachRadius = 400});
  String name;
  String path; // "arrived" voice
  LatLng point;
  double radius; // meters
  String? approachPath; // optional "approaching" voice
  double approachRadius; // meters

  Map<String, dynamic> toJson() => {
    'n': name,
    'p': path,
    'lat': point.latitude,
    'lng': point.longitude,
    'r': radius,
    'ap': approachPath,
    'ar': approachRadius,
  };

  factory VoiceTrigger.fromJson(Map<String, dynamic> j) => VoiceTrigger(
    j['n'],
    j['p'],
    LatLng(j['lat'], j['lng']),
    (j['r'] as num).toDouble(),
    approachPath: j['ap'],
    approachRadius: (j['ar'] as num?)?.toDouble() ?? 400,
  );
}

// ---------- Home ----------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final player = AudioPlayer();
  int next = 0; // index of the next stop to announce
  bool approached = false; // "approaching" voice already played for next stop
  List<VoiceTrigger> triggers = [];
  StreamSubscription<Position>? sub;

  @override
  void initState() {
    super.initState();
    _load();
    _startTracking();
  }

  @override
  void dispose() {
    sub?.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('triggers') ?? [];
    setState(() => triggers =
        raw.map((s) => VoiceTrigger.fromJson(jsonDecode(s))).toList());
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'triggers', triggers.map((t) => jsonEncode(t.toJson())).toList());
  }

  Future<void> _startTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      // Foreground service keeps tracking alive when the app is minimized.
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Voice Trigger',
        notificationText: 'Watching for your saved places',
        enableWakeLock: true,
      ),
    )
        : AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
      pauseLocationUpdatesAutomatically: false,
    );

    sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition);
  }

  void _onPosition(Position pos) {
    if (triggers.isEmpty) return;
    if (next >= triggers.length) next = 0;
    final t = triggers[next];
    final d = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, t.point.latitude, t.point.longitude);
    if (d <= t.radius) {
      player.play(DeviceFileSource(t.path)); // "arrived"
      setState(() {
        next = (next + 1) % triggers.length; // loop the route
        approached = false;
      });
    } else if (!approached &&
        t.approachPath != null &&
        d <= t.approachRadius) {
      approached = true;
      player.play(DeviceFileSource(t.approachPath!)); // "approaching"
    }
  }

  Future<void> _add() async {
    final t = await Navigator.push<VoiceTrigger>(
        context, MaterialPageRoute(builder: (_) => const AddPage()));
    if (t == null) return;
    setState(() => triggers.add(t));
    await _save();
  }

  Future<void> _delete(int i) async {
    final t = triggers.removeAt(i);
    if (next >= triggers.length) next = 0;
    approached = false;
    for (final f in [t.path, t.approachPath]) {
      if (f == null) continue;
      try {
        await File(f).delete();
      } catch (_) {}
    }
    setState(() {});
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Trigger')),
      floatingActionButton:
      FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: triggers.isEmpty
          ? const Center(child: Text('No voices yet. Tap + to add one.'))
          : ReorderableListView.builder(
        itemCount: triggers.length,
        onReorder: (a, b) {
          if (b > a) b--;
          setState(() {
            triggers.insert(b, triggers.removeAt(a));
            next = 0;
            approached = false;
          });
          _save();
        },
        itemBuilder: (_, i) {
          final t = triggers[i];
          return ListTile(
            key: ValueKey(t.path),
            selected: i == next,
            onTap: () => setState(() {
              next = i;
              approached = false;
            }),
            title: Text('${i + 1}. ${t.name}'),
            subtitle: Text(
                '${t.point.latitude.toStringAsFixed(5)}, ${t.point.longitude.toStringAsFixed(5)} • ${t.radius.round()} m'),
            leading: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => player.play(DeviceFileSource(t.path)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _delete(i),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Add page: record + pick location ----------
class AddPage extends StatefulWidget {
  const AddPage({super.key});
  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final rec = AudioRecorder();
  final nameCtl = TextEditingController();
  String? path; // arrived voice
  String? approachPath; // optional approaching voice
  String? recordingWhich; // 'arrive' | 'approach' | null
  bool get recording => recordingWhich != null;
  double approachRadius = 400;
  LatLng? center;
  LatLng? point;
  double radius = 150;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    rec.dispose();
    nameCtl.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => center = LatLng(p.latitude, p.longitude));
    } catch (_) {
      setState(() => center = const LatLng(0, 0));
    }
  }

  Future<void> _toggleRecord(String which) async {
    if (recordingWhich == which) {
      await rec.stop();
      setState(() => recordingWhich = null);
      return;
    }
    if (recording || !await rec.hasPermission()) return;
    final dir = await getApplicationDocumentsDirectory();
    final f =
        '${dir.path}/${which}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await rec.start(const RecordConfig(), path: f);
    setState(() {
      recordingWhich = which;
      if (which == 'arrive') {
        path = f;
      } else {
        approachPath = f;
      }
    });
  }

  Widget _recordRow(String label, String which, String? file) {
    final active = recordingWhich == which;
    return Row(children: [
      Expanded(child: Text(label)),
      if (file != null && !active)
        const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.check_circle, color: Colors.green)),
      IconButton.filled(
        onPressed: () => _toggleRecord(which),
        icon: Icon(active ? Icons.stop : Icons.mic),
        style:
        IconButton.styleFrom(backgroundColor: active ? Colors.red : null),
      ),
    ]);
  }

  void _saveAndClose() {
    if (path == null || point == null || recording) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Record a voice and tap the map to pick a spot.')));
      return;
    }
    final name = nameCtl.text.trim().isEmpty ? 'Voice' : nameCtl.text.trim();
    Navigator.pop(
        context,
        VoiceTrigger(name, path!, point!, radius,
            approachPath: approachPath, approachRadius: approachRadius));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New voice trigger'), actions: [
        TextButton(onPressed: _saveAndClose, child: const Text('Save')),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Column(children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Stop name'),
              ),
              _recordRow('Arrived voice', 'arrive', path),
              _recordRow(
                  'Approaching voice (optional)', 'approach', approachPath),
            ]),
          ),
          Row(children: [
            const SizedBox(width: 12),
            Text('Arrived: ${radius.round()} m'),
            Expanded(
              child: Slider(
                value: radius,
                min: 50,
                max: 500,
                onChanged: (v) => setState(() => radius = v),
              ),
            ),
          ]),
          Row(children: [
            const SizedBox(width: 12),
            Text('Approaching: ${approachRadius.round()} m'),
            Expanded(
              child: Slider(
                value: approachRadius,
                min: 200,
                max: 1000,
                onChanged: (v) => setState(() => approachRadius = v),
              ),
            ),
          ]),
          Expanded(
            child: center == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
              options: MapOptions(
                initialCenter: center!,
                initialZoom: 16,
                onTap: (_, p) => setState(() => point = p),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.voice_trigger',
                ),
                if (point != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: point!,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ]),
                if (point != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: point!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}