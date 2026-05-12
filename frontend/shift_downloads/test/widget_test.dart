import 'package:flutter_test/flutter_test.dart';

import 'package:shift_downloads/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShiftDownloadsApp());
    expect(find.text('SHiFT//DOWNLOADS'), findsOneWidget);
  });
}
