import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/bookstore/presentation/pages/home_page.dart';
import '../../features/bookstore/presentation/pages/novel_detail_page.dart';
import '../../features/reader/presentation/pages/reader_page.dart';
import '../../features/bookshelf/presentation/pages/bookshelf_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/novel/:id',
        name: 'novel-detail',
        builder: (context, state) => NovelDetailPage(novelId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/read/:chapterId',
        name: 'reader',
        builder: (context, state) => ReaderPage(chapterId: state.pathParameters['chapterId']!),
      ),
      GoRoute(
        path: '/bookshelf',
        name: 'bookshelf',
        builder: (context, state) => const BookshelfPage(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
  );
});
