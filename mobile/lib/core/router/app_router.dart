import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const Placeholder(), // TODO: BookstorePage
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const Placeholder(), // TODO: LoginPage
      ),
      GoRoute(
        path: '/novel/:id',
        name: 'novel-detail',
        builder: (context, state) => const Placeholder(), // TODO: NovelDetailPage
      ),
      GoRoute(
        path: '/read/:chapterId',
        name: 'reader',
        builder: (context, state) => const Placeholder(), // TODO: ReaderPage
      ),
      GoRoute(
        path: '/bookshelf',
        name: 'bookshelf',
        builder: (context, state) => const Placeholder(), // TODO: BookshelfPage
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const Placeholder(), // TODO: SearchPage
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const Placeholder(), // TODO: ProfilePage
      ),
    ],
  );
});
