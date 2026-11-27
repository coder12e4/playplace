import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_trigger.dart';

class VoiceTriggersController extends GetxController {
  final RxList<VoiceTrigger> triggers = <VoiceTrigger>[].obs;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('triggers') ?? <String>[];
    triggers.assignAll(raw.map((value) =>
      VoiceTrigger.fromJson(jsonDecode(value) as Map<String, dynamic>)));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('triggers',
      triggers.map((trigger) => jsonEncode(trigger.toJson())).toList());
  }

  Future<void> add(VoiceTrigger trigger) async {
    triggers.add(trigger);
    await _persist();
  }

  Future<VoiceTrigger> removeAt(int index) async {
    final removed = triggers.removeAt(index);
    await _persist();
    return removed;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final item = triggers.removeAt(oldIndex);
    triggers.insert(newIndex, item);
    await _persist();
  }
}
