import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_music/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const VibeMusicApp());
  });
}
