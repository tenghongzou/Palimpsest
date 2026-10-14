import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/bookstore/presentation/pages/category_list_page.dart';
import '../../features/bookstore/presentation/pages/home_page.dart';
import '../../features/bookstore/presentation/pages/novel_detail_page.dart';
import '../../features/bookstore/presentation/pages/novel_list_page.dart';
import '../../features/bookstore/presentation/pages/ranking_page.dart';
import '../../features/devices/presentation/pages/devices_page.dart';
import '../../features/downloads/presentation/pages/downloads_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/profile/presentation/pages/reading_history_page.dart';
import '../../features/profile/presentation/pages/reading_settings_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/reader/presentation/pages/bookmarks_page.dart';
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
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) => ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/novel/:id',
        name: 'novel-detail',
        builder: (context, state) => NovelDetailPage(novelId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/novels',
        name: 'novels',
        builder: (context, state) => NovelListPage(
          category: state.uri.queryParameters['category'],
          title: state.uri.queryParameters['title'],
          sortBy: state.uri.queryParameters['sort_by'],
        ),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        builder: (context, state) => const CategoryListPage(),
      ),
      GoRoute(
        path: '/ranking/:type',
        name: 'ranking',
        builder: (context, state) => RankingPage(
          type: state.pathParameters['type']!,
          period: state.uri.queryParameters['period'] ?? 'weekly',
        ),
      ),
      GoRoute(
        path: '/read/:chapterId',
        name: 'reader',
        builder: (context, state) => ReaderPage(
          chapterId: state.pathParameters['chapterId']!,
          initialParagraph: int.tryParse(state.uri.queryParameters['p'] ?? ''),
          focusCommentId: state.uri.queryParameters['comment'],
        ),
      ),
      GoRoute(
        path: '/bookshelf',
        name: 'bookshelf',
        builder: (context, state) => const BookshelfPage(),
      ),
      GoRoute(
        path: '/bookmarks',
        name: 'bookmarks',
        builder: (context, state) => const BookmarksPage(),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (context, state) => const DownloadsPage(),
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
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const ReadingHistoryPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'password',
            name: 'change-password',
            builder: (context, state) => const ChangePasswordPage(),
          ),
          GoRoute(
            path: 'reading',
            name: 'reading-settings',
            builder: (context, state) => const ReadingSettingsPage(),
          ),
          GoRoute(
            path: 'devices',
            name: 'devices',
            builder: (context, state) => const DevicesPage(),
          ),
        ],
      ),
    ],
  );
});
