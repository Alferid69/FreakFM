import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/utils/formatters.dart';

void main() {
  test('formatDuration uses m:ss and h:mm:ss', () {
    expect(formatDuration(const Duration(seconds: 7)), '0:07');
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatDuration(const Duration(seconds: -4)), '0:00');
  });

  test('plural picks singular for exactly one', () {
    expect(plural(1, 'song'), '1 song');
    expect(plural(0, 'song'), '0 songs');
    expect(plural(2, 'album'), '2 albums');
    expect(plural(3, 'child', 'children'), '3 children');
  });
}
