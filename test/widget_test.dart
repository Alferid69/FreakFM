import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/main.dart';

void main() {
  testWidgets('app starts on Home with the Spotify-style bottom bar', (WidgetTester tester) async {
    await tester.pumpWidget(const FreakMusicPlayerApp());
    expect(find.byKey(const ValueKey('nav_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_library')), findsOneWidget);
    expect(find.text('Your Library'), findsWidgets);
  });
}
