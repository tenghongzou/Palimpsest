import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bookmark_list.dart';

/// All bookmarks across novels.
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的書籤')),
      body: BookmarkList(
        onOpen: (b) => context.push('/read/${b.chapterId}?p=${b.paragraphIndex}'),
      ),
    );
  }
}
