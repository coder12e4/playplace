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
import 'dart:ui' show ImageFilter;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'features/announcements/models/voice_trigger.dart';
import 'features/announcements/controllers/voice_triggers_controller.dart';
import 'features/routes/controllers/route_progress_controller.dart';
import 'app/bindings/app_binding.dart';
import 'admin/super_admin_dashboard_page.dart';
import 'admin/super_admin_binding.dart';
import 'app/routes/app_routes.dart';
import 'bus_routes_page.dart';
import 'driver_calendar_page.dart';
import 'admin/admin_gate.dart';
import 'driver_auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PlayPlaceApp());
}

class PlayPlaceApp extends StatelessWidget {
  const PlayPlaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialBinding: AppBinding(),
      initialRoute: kIsWeb ? AppRoutes.admin : AppRoutes.driver,
      getPages: [
        GetPage(name: AppRoutes.driver, page: () => const DriverAuthGate()),
        GetPage(name: AppRoutes.admin, page: () => const AdminGate()),
        GetPage(name: AppRoutes.superAdmin, page: () => const SuperAdminDashboardPage(), binding: SuperAdminBinding()),
        GetPage(name: AppRoutes.home, page: () => const Home()),
      ],
      title: 'PlayPlace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEAF8EF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF55B879),
          brightness: Brightness.light,
          surface: const Color(0xFFF5FCF7),
          primary: const Color(0xFF328B55),
          onPrimary: Colors.white,
          secondary: const Color(0xFF8BCFA3),
          onSurface: const Color(0xFF173D29),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF173D29),
          displayColor: const Color(0xFF173D29),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF17452D),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xDDFBFFFC),
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: const Color(0xFF80B996).withOpacity(0.28)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xDDFBFFFC),
          labelStyle: const TextStyle(color: Color(0xFF47775A)),
          hintStyle: const TextStyle(color: Color(0xFF779582)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x3380B996)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x3380B996)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF55A875), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4EAA70),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4EAA70),
          foregroundColor: Colors.white,
        ),
      ),
      
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Home()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF8EF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF65BD83),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.place_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 22),
            const Text(
              'PlayPlace',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Location-aware audio for everyone',
              style: TextStyle(color: Color(0xFF62816D), fontSize: 14),
            ),
            const SizedBox(height: 34),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4EAA70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Model ----------

// ---------- Home ----------
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final voiceController = Get.find<VoiceTriggersController>();
  final routeProgress = Get.find<RouteProgressController>();
  final player = AudioPlayer();
  final FlutterTts tts = FlutterTts();
  StreamSubscription<Position>? sub;
  bool announcing = false;

  @override
  void initState() {
    super.initState();
    voiceController.load();
    _initializeTts();
    _startTracking();
  }

  @override
  void dispose() {
    sub?.cancel();
    player.dispose();
    tts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);
  }

  Future<void> _announce(VoiceTrigger trigger, {required bool arrived}) async {
    if (announcing) return;
    announcing = true;
    try {
      final audioPath = arrived ? trigger.path : trigger.approachPath;
      if (audioPath != null && await File(audioPath).exists()) {
        await tts.stop();
        await player.stop();
        await player.play(DeviceFileSource(audioPath));
        return;
      }
      final template = arrived ? trigger.arrivalTemplate : trigger.approachTemplate;
      final fallback = arrived
          ? 'You have arrived at ${trigger.name}.'
          : 'You are approaching ${trigger.name}.';
      final message = template.trim().isEmpty
          ? fallback
          : template.replaceAll('{name}', trigger.name);
      await player.stop();
      await tts.setLanguage(trigger.languageCode);
      await tts.speak(message);
    } catch (error) {
      debugPrint('Voice announcement failed: $error');
    } finally {
      announcing = false;
    }
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
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'PlayPlace',
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

  void _showLocationNotification({
    required String title,
    required String message,
    required IconData icon,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFF8FFF9),
        elevation: 8,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF8FC6A1)),
        ),
        content: Row(
          children: [
            Icon(icon, color: const Color(0xFF328B55), size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(
                    color: Color(0xFF17452D), fontWeight: FontWeight.w700,
                  )),
                  Text(message, style: const TextStyle(color: Color(0xFF52745E))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPosition(Position pos) {
    final triggers = voiceController.triggers.toList();
    if (triggers.isEmpty || announcing) return;
    final nextIndex = routeProgress.nextIndex.value;
    final approached = routeProgress.approached.value;
    final index = nextIndex >= triggers.length ? 0 : nextIndex;
    final trigger = triggers[index];
    final distance = Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      trigger.point.latitude, trigger.point.longitude,
    );
    if (distance <= trigger.radius) {
      _showLocationNotification(
        title: 'Arrived at ${trigger.name}',
        message: 'You have reached this saved location.',
        icon: Icons.location_on,
      );
      _announce(trigger, arrived: true);
      routeProgress.advance(triggers.length);
    } else if (!approached && distance <= trigger.approachRadius) {
      routeProgress.markApproached();
      _showLocationNotification(
        title: 'Approaching ${trigger.name}',
        message: 'About ${distance.round()} m away.',
        icon: Icons.near_me,
      );
      _announce(trigger, arrived: false);
    } else if (distance > trigger.approachRadius && approached) {
      routeProgress.resetApproached();
    }
  }

  Future<void> _add() async {
    final trigger = await Navigator.push<VoiceTrigger>(
      context,
      MaterialPageRoute(builder: (_) => const AddPage()),
    );
    if (trigger == null || !mounted) return;
    await voiceController.add(trigger);
  }

  Future<void> _delete(int index) async {
    final trigger =
        await voiceController.removeAt(index);
    routeProgress.normalize(voiceController.triggers.length);
    for (final file in [trigger.path, trigger.approachPath]) {
      if (file == null) continue;
      try {
        await File(file).delete();
      } catch (_) {
        // A missing recording should not prevent deleting its saved trigger.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final triggers = voiceController.triggers.toList();
      final nextIndex = routeProgress.nextIndex.value;
      return Scaffold(
      appBar: AppBar(
        title: const Text('PlayPlace'),
        actions: [
          IconButton(
            tooltip: 'Bus routes',
            icon: const Icon(Icons.directions_bus),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusRoutesPage()),
            ),
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2FBF5), Color(0xFFE2F4E8), Color(0xFFD5EEDD)],
          ),
        ),
        child: triggers.isEmpty
            ? const Center(child: Text('No voices yet. Tap + to add one.'))
            : ReorderableListView.builder(
              itemCount: triggers.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                voiceController.reorder(oldIndex, newIndex);
                routeProgress.select(0);
              },
              itemBuilder: (_, index) {
                final trigger = triggers[index];
                return Padding(
                  key: ValueKey('${trigger.name}_${trigger.point.latitude}_${trigger.point.longitude}'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.68),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF80B996).withOpacity(0.30)),
                        ),
                        child: ListTile(
                  selected: index == nextIndex,
                  onTap: () => routeProgress.select(index),
                  title: Text('${index + 1}. ${trigger.name}'),
                  subtitle: Text(
                    '${trigger.point.latitude.toStringAsFixed(5)}, '
                    '${trigger.point.longitude.toStringAsFixed(5)} • '
                    '${trigger.radius.round()} m',
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _announce(trigger, arrived: true),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFFA7A7)),
                    onPressed: () => _delete(index),
                  ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
      );
    });
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
  final arrivalCtl = TextEditingController();
  final approachCtl = TextEditingController();
  final previewTts = FlutterTts();
  String languageCode = 'en-US';
  Position? currentPosition;
  final MapController mapController = MapController();
  bool mapReady = false;
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
    arrivalCtl.text = 'You have arrived at {name}.';
    approachCtl.text = 'You are approaching {name}.';
    _locate();
  }

  @override
  void dispose() {
    rec.dispose();
    previewTts.stop();
    nameCtl.dispose();
    arrivalCtl.dispose();
    approachCtl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable device location services.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required to fetch your position.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final current = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        currentPosition = position;
        center = current;
        point = current;
      });
      if (mapReady) mapController.move(current, 18);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location fetched (±${position.accuracy.toStringAsFixed(0)} m)'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not fetch location: $error')),
      );
    }
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

  Future<void> _previewSpeech({required bool arrived}) async {
    final name = nameCtl.text.trim().isEmpty ? 'this location' : nameCtl.text.trim();
    final template = arrived ? arrivalCtl.text : approachCtl.text;
    final fallback = arrived ? 'You have arrived at $name.' : 'You are approaching $name.';
    final message = template.trim().isEmpty ? fallback : template.replaceAll('{name}', name);
    try {
      await previewTts.setLanguage(languageCode);
      await previewTts.setSpeechRate(0.45);
      await previewTts.speak(message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS preview failed: $error')),
      );
    }
  }

  void _saveAndClose() {
    if (point == null || recording) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a map location and stop any active recording.')));
      return;
    }
    final name = nameCtl.text.trim().isEmpty ? 'Location' : nameCtl.text.trim();
    Navigator.pop(
      context,
      VoiceTrigger(
        name, path, point!, radius,
        approachPath: approachPath,
        approachRadius: approachRadius,
        languageCode: languageCode,
        arrivalTemplate: arrivalCtl.text.trim(),
        approachTemplate: approachCtl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New voice trigger'), actions: [
        TextButton(onPressed: _saveAndClose, child: const Text('Save')),
      ]),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2FBF5), Color(0xFFE2F4E8), Color(0xFFD5EEDD)],
          ),
        ),
        child: Column(
        children: [
          Flexible(
            flex: 0,
            fit: FlexFit.loose,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF80B996).withOpacity(0.30)),
                  ),
                  child: Column(children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Stop name'),
              ),
              _recordRow('Arrived voice', 'arrive', path),
              _recordRow(
                  'Approaching voice (optional)', 'approach', approachPath),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: languageCode,
                decoration: const InputDecoration(labelText: 'Announcement language', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                  DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                  DropdownMenuItem(value: 'ml-IN', child: Text('Malayalam')),
                  DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                  DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    languageCode = value;

                    // Switch the built-in announcement templates with the
                    // selected language. Users can still edit either message.
                    if (value == 'ml-IN') {
                      approachCtl.text =
                          '{name} എന്ന സ്ഥലത്തിന് സമീപം എത്തിയിരിക്കുന്നു.';
                      arrivalCtl.text =
                          'നിങ്ങൾ {name} എന്ന സ്ഥലത്ത് എത്തിയിരിക്കുന്നു.';
                    } else {
                      approachCtl.text = 'You are approaching {name}.';
                      arrivalCtl.text = 'You have arrived at {name}.';
                    }
                  });
                },
              ),
              TextField(
                controller: approachCtl,
                decoration: const InputDecoration(
                  labelText: 'Automatic approaching message',
                  helperText: 'Use {name} for the location name.',
                  isDense: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _previewSpeech(arrived: false),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Preview approach'),
                ),
              ),
              TextField(
                controller: arrivalCtl,
                decoration: const InputDecoration(
                  labelText: 'Automatic arrival message',
                  helperText: 'Use {name} for the location name.',
                  isDense: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _previewSpeech(arrived: true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Preview arrival'),
                ),
              ),
                  ]),
                ),
              ),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Fetch current location'),
                ),
                const SizedBox(height: 6),
                if (point == null)
                  const Text(
                    'No location selected. Fetch your location or tap a point on the map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                else ...[
                  Text('Latitude: ${point!.latitude.toStringAsFixed(7)}',
                      textAlign: TextAlign.center),
                  Text('Longitude: ${point!.longitude.toStringAsFixed(7)}',
                      textAlign: TextAlign.center),
                  if (currentPosition != null)
                    Text('GPS accuracy: ±${currentPosition!.accuracy.toStringAsFixed(1)} m',
                        textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: center == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center!,
                initialZoom: 16,
                onMapReady: () => mapReady = true,
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
            ),
          ),
          ])
      ),
      );

  }
}