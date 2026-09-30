import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/main.dart';

void main() {
  testWidgets('Music player app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FreakMusicPlayerApp());
    expect(find.text('FREAK PLAYER'), findsOneWidget);
  });
}
