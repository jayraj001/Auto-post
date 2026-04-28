import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:autopost_ai/main.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AutoPostApp()));
    await tester.pumpAndSettle();

    expect(find.text('AutoPost AI'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
