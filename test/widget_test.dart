import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tapline/app.dart';

void main() {
  setUpAll(() {
    // Don't let tests hit the network for fonts — fall back to the
    // platform default font instead. See the "Fonts" note in
    // README.md for why google_fonts fetches at runtime.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Hub screen shows all three mode panels', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ConvoyApp()));
    await tester.pumpAndSettle();

    expect(find.text('CLASSIC'), findsOneWidget);
    expect(find.text('CAPACITY'), findsOneWidget);
    expect(find.text('SIGNAL'), findsOneWidget);
  });

  testWidgets('Tapping a mode panel opens the coming-soon placeholder',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ConvoyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CLASSIC'));
    await tester.pumpAndSettle();

    expect(find.text('CLASSIC MODE'), findsOneWidget);
  });
}
