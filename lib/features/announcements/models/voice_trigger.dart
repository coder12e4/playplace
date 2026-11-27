import 'package:latlong2/latlong.dart';

class VoiceTrigger {
  VoiceTrigger(this.name, this.path, this.point, this.radius,
      {this.approachPath,
      this.approachRadius = 400,
      this.languageCode = 'en-US',
      this.arrivalTemplate = 'You have arrived at {name}.',
      this.approachTemplate = 'You are approaching {name}.'});
  String name;
  String? path;
  LatLng point;
  double radius;
  String? approachPath;
  double approachRadius;
  String languageCode;
  String arrivalTemplate;
  String approachTemplate;

  Map<String, dynamic> toJson() => {
    'n': name, 'p': path, 'lat': point.latitude, 'lng': point.longitude,
    'r': radius, 'ap': approachPath, 'ar': approachRadius,
    'lang': languageCode,
    'arrivalTemplate': arrivalTemplate,
    'approachTemplate': approachTemplate,
  };

  factory VoiceTrigger.fromJson(Map<String, dynamic> j) => VoiceTrigger(
    j['n'] as String? ?? 'Location',
    j['p'] as String?,
    LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
    (j['r'] as num).toDouble(),
    approachPath: j['ap'] as String?,
    approachRadius: (j['ar'] as num?)?.toDouble() ?? 400,
    languageCode: j['lang'] as String? ?? 'en-US',
    arrivalTemplate: j['arrivalTemplate'] as String? ?? 'You have arrived at {name}.',
    approachTemplate: j['approachTemplate'] as String? ?? 'You are approaching {name}.',
  );
}
