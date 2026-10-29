import 'package:flutter_test/flutter_test.dart';
import 'package:citypos/main.dart';

void main() {
  testWidgets('Adom Mmoroso ENT. POS smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AdomMmorosoApp());
  });
}
