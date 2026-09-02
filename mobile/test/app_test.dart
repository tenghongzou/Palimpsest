import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palimpsest/app.dart';
import 'package:palimpsest/features/bookstore/domain/entities/novel.dart';
import 'package:palimpsest/features/bookstore/presentation/providers/bookstore_provider.dart';

void main() {
  testWidgets('PalimpsestApp renders without error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeNovelsProvider('views').overrideWith((ref) async => <Novel>[]),
          homeNovelsProvider('latest').overrideWith((ref) async => <Novel>[]),
        ],
        child: const PalimpsestApp(),
      ),
    );

    expect(find.byType(PalimpsestApp), findsOneWidget);
  });
}
