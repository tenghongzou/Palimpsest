import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bookmark_list.dart';
import '../../../../core/l10n/l10n.dart';

/// All bookmarks across novels.
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myBookmarks)),
      body: BookmarkList(
        onOpen: (b) => context.push('/read/${b.chapterId}?p=${b.paragraphIndex}'),
      ),
    );
  }
}
