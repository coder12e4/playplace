import 'package:get/get.dart';

class RouteProgressController extends GetxController {
  final RxInt nextIndex = 0.obs;
  final RxBool approached = false.obs;

  void select(int index) {
    nextIndex.value = index;
    approached.value = false;
  }

  void markApproached() => approached.value = true;
  void resetApproached() => approached.value = false;

  void advance(int count) {
    nextIndex.value = count == 0 ? 0 : (nextIndex.value + 1) % count;
    approached.value = false;
  }

  void normalize(int count) {
    if (count == 0 || nextIndex.value >= count) select(0);
  }
}
