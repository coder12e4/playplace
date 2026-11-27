import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'glass_card.dart';
import 'driver_performance.dart';
import 'package:geolocator/geolocator.dart';

import 'bus_routes_page.dart';

class BusRouteRunPage extends StatefulWidget {
  const BusRouteRunPage({super.key, required this.route});

  final BusRoute route;

  @override
  State<BusRouteRunPage> createState() => _BusRouteRunPageState();
}

class _BusRouteRunPageState extends State<BusRouteRunPage> {
  static const double _approachRadiusMeters = 500;
  static const double _arrivalRadiusMeters = 60;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Position>? _positionSubscription;
  int _stopIndex = 0;
  double? _distanceMeters;
  bool _running = false;
  bool _processing = false;
  bool _approachAnnounced = false;
  bool _arrivalAnnounced = false;
  bool _finished = false;
  bool _pausedWithAudio = false;
  String _status = 'Ready to start';
  DateTime? _startedAt;
  final Stopwatch _activeClock = Stopwatch();
  Position? _lastGoodPosition;
  double _distanceTravelledMeters = 0;
  double _accuracyTotalMeters = 0;
  int _accuracySamples = 0;
  bool _recordSaved = false;

  double get _averageAccuracy => _accuracySamples == 0 ? 0 : _accuracyTotalMeters / _accuracySamples;
  double get _averageSpeedKmh => _activeClock.elapsed.inSeconds == 0 ? 0 :
      (_distanceTravelledMeters / 1000) / (_activeClock.elapsed.inSeconds / 3600);

  BusStop? get _currentStop =>
      _stopIndex < widget.route.stops.length ? widget.route.stops[_stopIndex] : null;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (_running || _finished) return;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showMessage('Turn on device location to start route announcements.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Location permission is required for GPS announcements.');
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      if (!mounted) return;
      _startedAt ??= DateTime.now();
      _activeClock.start();
      _lastGoodPosition = null;
      if (_pausedWithAudio) {
        await _player.resume();
        _pausedWithAudio = false;
      }
      setState(() {
        _running = true;
        _status = 'GPS tracking active';
        _distanceMeters = _currentStop == null
            ? null
            : Geolocator.distanceBetween(
                initial.latitude,
                initial.longitude,
                _currentStop!.point.latitude,
                _currentStop!.point.longitude,
              );
      });
      await _handlePosition(initial);
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        _handlePosition,
        onError: (Object error) {
          if (mounted) setState(() => _status = 'GPS error: $error');
        },
      );
    } catch (error) {
      _showMessage('Could not start GPS tracking: $error');
    }
  }

  Future<void> _pauseTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _player.pause();
    _activeClock.stop();
    _lastGoodPosition = null;
    _pausedWithAudio = true;
    if (mounted) {
      setState(() {
        _running = false;
        _status = 'Paused';
      });
    }
  }

  Future<void> _endRoute() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _player.stop();
    _activeClock.stop();
    await _savePerformanceRecord();
    if (mounted) {
      setState(() {
        _running = false;
        _finished = true;
        _status = 'Route ended';
      });
    }
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

  void _capturePerformancePosition(Position position) {
    // Discard weak fixes so GPS drift does not inflate the route distance.
    if (position.accuracy <= 0 || position.accuracy > 50) return;
    _accuracyTotalMeters += position.accuracy;
    _accuracySamples++;
    final previous = _lastGoodPosition;
    if (previous != null) {
      final delta = Geolocator.distanceBetween(previous.latitude, previous.longitude,
        position.latitude, position.longitude);
      // Ignore stationary GPS jitter and implausible jumps between fixes.
      if (delta >= 2 && delta <= 400) _distanceTravelledMeters += delta;
    }
    _lastGoodPosition = position;
  }

  Future<void> _savePerformanceRecord() async {
    if (_recordSaved || _startedAt == null) return;
    _recordSaved = true;
    final ended = DateTime.now();
    final seconds = _activeClock.elapsed.inSeconds;
    final record = DriverTripRecord(
      id: '${widget.route.name}_${_startedAt!.microsecondsSinceEpoch}',
      routeName: widget.route.name,
      startedAt: _startedAt!,
      endedAt: ended,
      durationSeconds: seconds,
      distanceMeters: _distanceTravelledMeters,
      averageSpeedKmh: seconds == 0 ? 0 : (_distanceTravelledMeters / 1000) / (seconds / 3600),
      averageAccuracyMeters: _averageAccuracy,
      stopsCompleted: _stopIndex,
    );
    await DriverPerformanceStore.save(record);
  }

  Future<void> _handlePosition(Position position) async {
    if (!_running) return;
    _capturePerformancePosition(position);
    final stop = _currentStop;
    if (stop == null || _processing) return;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      stop.point.latitude,
      stop.point.longitude,
    );
    if (mounted) setState(() => _distanceMeters = distance);

    _processing = true;
    try {
      if (distance <= _approachRadiusMeters && !_approachAnnounced) {
        _approachAnnounced = true;
        if (mounted) {
          setState(() => _status = 'Approaching ${stop.name}');
          _showLocationNotification(
            title: 'Approaching ${stop.name}',
            message: 'Bus is about ${distance.round()} m from this stop.',
            icon: Icons.near_me,
          );
        }
        await _playRepeated(stop.arrivingAudio, stop.arrivingRepeatCount);
      }
      if (!_running) return;
      if (distance <= _arrivalRadiusMeters && !_arrivalAnnounced) {
        _arrivalAnnounced = true;
        if (mounted) {
          setState(() => _status = 'Arrived at ${stop.name}');
          _showLocationNotification(
            title: 'Arrived at ${stop.name}',
            message: 'The bus has reached this stop.',
            icon: Icons.location_on,
          );
        }
        await _playRepeated(stop.arrivedAudio, stop.arrivedRepeatCount);
        if (!_running) return;
        if (mounted) {
          setState(() {
            _stopIndex++;
            _approachAnnounced = false;
            _arrivalAnnounced = false;
            _distanceMeters = null;
            if (_currentStop == null) {
              _finished = true;
              _running = false;
              _status = 'All stops completed';
            } else {
              _status = 'Next stop: ${_currentStop!.name}';
            }
          });
        }
        if (_finished) {
          _activeClock.stop();
          await _savePerformanceRecord();
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _playRepeated(String? path, int count) async {
    if (path == null) return;
    final isRemote = path.startsWith('https://');
    if (!isRemote && !File(path).existsSync()) return;
    for (var i = 0; i < count.clamp(1, 10); i++) {
      if (!_running) return;
      final completed = _player.onPlayerComplete.first;
      await _player.play(isRemote ? UrlSource(path) : DeviceFileSource(path));
      try {
        await completed.timeout(const Duration(minutes: 3));
      } on TimeoutException {
        await _player.stop();
        return;
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stop = _currentStop;
    return Scaffold(
      appBar: AppBar(title: Text(widget.route.name)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2FBF5), Color(0xFFE2F4E8), Color(0xFFD5EEDD)],
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.directions_bus, size: 48),
            const SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (stop == null)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('All registered stops have been completed.'),
                ),
              )
            else
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('STOP ${_stopIndex + 1} OF ${widget.route.stops.length}',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(stop.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(_distanceMeters == null
                          ? 'Waiting for GPS location'
                          : '${_distanceMeters!.round()} m away'),
                      const Divider(height: 24),
                      Text('Trip distance: ${(_distanceTravelledMeters / 1000).toStringAsFixed(2)} km'),
                      Text('Average speed: ${_averageSpeedKmh.toStringAsFixed(1)} km/h'),
                      Text('GPS accuracy: ${_accuracySamples == 0 ? 'Waiting for GPS' : '±${_averageAccuracy.toStringAsFixed(0)} m'}'),
                      Text('Arriving announcement: ${stop.arrivingRepeatCount}×'),
                      Text('Arrived announcement: ${stop.arrivedRepeatCount}×'),
                      const SizedBox(height: 8),
                      const Text(
                        'Arriving alert: within 500 m  •  Arrived alert: within 60 m',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            if (_finished)
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Close'),
              )
            else if (!_running)
              FilledButton.icon(
                onPressed: _startTracking,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start / Resume GPS'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _pauseTracking,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _finished ? null : _endRoute,
              icon: const Icon(Icons.stop),
              label: const Text('End route'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep PlayPlace open while driving. GPS announcements may pause if the operating system stops the app in the background.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF62816D)),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
