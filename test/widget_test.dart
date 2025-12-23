import 'package:thinkcyber/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dashboard renders fallback state when data fails', (tester) async {
    await tester.pumpWidget(const ThinkCyberApp());
    await tester.pump();

    expect(find.text('Weekly momentum'), findsOneWidget);
  });
}
