import 'package:get/get.dart';
import '../../features/announcements/controllers/voice_triggers_controller.dart';
import '../../features/routes/controllers/route_progress_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<VoiceTriggersController>(VoiceTriggersController(), permanent: true);
    Get.put<RouteProgressController>(RouteProgressController(), permanent: true);
  }
}
