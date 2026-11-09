
import 'package:flutter_test/flutter_test.dart';
import 'package:wordle/main.dart';

void main() {
  testWidgets('Wordle Plus loads successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WordleApp());
    await tester.pumpAndSettle();

    expect(find.text('WORDLE PLUS'), findsOneWidget);
  });
}
