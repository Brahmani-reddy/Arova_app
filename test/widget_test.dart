import 'package:flutter_test/flutter_test.dart';
import 'package:arova/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArovaApp());
    expect(find.text('AROVA'), findsWidgets);
  });
}
