import 'package:flutter_test/flutter_test.dart';
import 'package:playplace/main.dart';

void main() {
  testWidgets('shows the PlayPlace splash screen', (tester) async {
    await tester.pumpWidget(const PlayPlaceApp());

    expect(find.text('PlayPlace'), findsOneWidget);
    expect(find.text('Location-aware audio for everyone'), findsOneWidget);
  });
}
