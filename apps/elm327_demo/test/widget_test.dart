import 'package:elm327_demo/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the device picker screen on launch', (tester) async {
    await tester.pumpWidget(const Elm327DemoApp());
    await tester.pump();

    expect(find.text('Choose an ELM327 adapter'), findsOneWidget);
  });
}
