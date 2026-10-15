import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/auth/presentation/providers/auth_provider.dart';
import 'package:palimpsest/features/bookstore/domain/entities/recommendation.dart';

import '../support/fake_api.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

Map<String, dynamic> otherNovel(int i, {String? author}) => {
      ...novelJson(),
      'id': '00000000-0000-4000-8000-00000000000$i',
      'title': '推薦作品$i',
      'author_name': author ?? '作者$i',
    };

Map<String, dynamic> item(int i, String type, String value) => {
      'novel': otherNovel(i),
      'reason': {'type': type, 'value': value},
    };

final _section = find.byKey(const ValueKey('home-recommendations'));
final _similar = find.byKey(const ValueKey('novel-similar'));

void main() {
  TestEnv? current;
  late TestEnv env;

  setUp(() => current = null);
  tearDown(() => current?.dispose());

  Future<TestEnv> create() async => current = await TestEnv.create();

  group('Recommendations.fromJson', () {
    test('parses items and reasons; unknown or nameless reasons read as popular', () {
      final r = Recommendations.fromJson({
        'personalized': true,
        'items': [
          item(1, 'category', '懸疑'),
          item(2, 'tag', '海港'),
          item(3, 'author', '林硯'),
          item(4, 'popular', ''),
          item(5, 'mood', 'x'),
          item(6, 'tag', ''),
        ],
      });
      expect(r.personalized, isTrue);
      expect(r.items.map((e) => e.novel.title), ['推薦作品1', '推薦作品2', '推薦作品3', '推薦作品4', '推薦作品5', '推薦作品6']);
      expect(r.items.map((e) => e.reason.type), [
        RecommendationReasonType.category,
        RecommendationReasonType.tag,
        RecommendationReasonType.author,
        RecommendationReasonType.popular,
        RecommendationReasonType.popular,
        RecommendationReasonType.popular,
      ]);
      expect(r.items.first.reason.value, '懸疑');
      expect(Recommendations.fromJson(const {}).items, isEmpty);
    });
  });

  group('home "for you"', () {
    testWidgets('personalized: title and a reason per novel; hidden once signed out; refetched on pull-to-refresh',
        (tester) async {
      env = await create();
      env.backend.api.on('GET', '/recommendations', (r) {
        final signedIn = r.headers['Authorization'] != null;
        return FakeResponse.ok(signedIn
            ? {
                'personalized': true,
                'items': [item(1, 'category', '懸疑'), item(2, 'tag', '海港'), item(3, 'author', '林硯')],
              }
            : {
                'personalized': false,
                'items': [item(4, 'popular', '')],
              });
      });
      await env.pumpApp(tester);

      expect(_section, findsOneWidget);
      expect(find.descendant(of: _section, matching: find.text('為你推薦')), findsOneWidget);
      expect(find.text('因為你喜歡懸疑'), findsOneWidget);
      expect(find.text('你常看的「海港」'), findsOneWidget);
      expect(find.text('林硯 的作品'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/recommendations').last.query['limit'], 12);

      // Opens the novel.
      await tester.tap(find.text('推薦作品1'));
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('GET', '/novels/00000000-0000-4000-8000-000000000001'), isNotEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      final before = env.backend.api.calls('GET', '/recommendations').length;
      final loggedOut = env.container(tester).read(authStateProvider.notifier).logout();
      await tester.pumpAndSettle();
      await loggedOut;
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('GET', '/recommendations').length, greaterThan(before));
      // Popular-only results duplicate the home page's popular section: hidden.
      expect(_section, findsNothing);
      expect(find.text('為你推薦'), findsNothing);

      final beforeRefresh = env.backend.api.calls('GET', '/recommendations').length;
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('GET', '/recommendations').length, greaterThan(beforeRefresh));
      await env.finish(tester);
    });

    testWidgets('hidden when empty', (tester) async {
      env = await create();
      env.backend.api.on('GET', '/recommendations', (_) => FakeResponse.ok({'personalized': true, 'items': []}));
      await env.pumpApp(tester);
      expect(env.backend.api.calls('GET', '/recommendations'), isNotEmpty);
      expect(_section, findsNothing);
      expect(find.text('編輯推薦'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('hidden when the request fails', (tester) async {
      env = await create();
      env.backend.api.on('GET', '/recommendations', (_) => FakeResponse.error(500, 50001, 'boom'));
      await env.pumpApp(tester);
      expect(_section, findsNothing);
      expect(find.text('編輯推薦'), findsOneWidget);
      await env.finish(tester);
    });
  });

  group('novel detail "similar"', () {
    testWidgets('lists similar novels and opens them', (tester) async {
      env = await create();
      env.backend.api.on('GET', '/novels/:id/similar',
          (_) => FakeResponse.ok([otherNovel(1, author: '甲'), otherNovel(2, author: '乙')]));
      await env.pumpApp(tester);
      await env.push(tester, '/novel/$novelId');
      expect(_similar, findsOneWidget);
      expect(find.text('相似作品'), findsOneWidget);
      expect(find.text('推薦作品1'), findsOneWidget);
      expect(find.text('乙'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/novels/$novelId/similar').last.query['limit'], 6);
      await env.finish(tester);
    });

    testWidgets('hidden when empty', (tester) async {
      env = await create();
      env.backend.api.on('GET', '/novels/:id/similar', (_) => FakeResponse.ok([]));
      await env.pumpApp(tester);
      await env.push(tester, '/novel/$novelId');
      expect(env.backend.api.calls('GET', '/novels/$novelId/similar'), isNotEmpty);
      expect(_similar, findsNothing);
      expect(find.text('相似作品'), findsNothing);
      await env.finish(tester);
    });
  });
}
