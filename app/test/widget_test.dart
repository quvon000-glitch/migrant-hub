import 'package:flutter_test/flutter_test.dart';
import 'package:migrant_hub/core/format.dart';

void main() {
  test('mm:ss formatting', () {
    expect(mmss(0), '0:00');
    expect(mmss(65), '1:05');
  });

  test('day label for today', () {
    expect(dayLabel(DateTime.now()), 'Bugun');
  });
}
