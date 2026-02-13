import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/novel.dart';

class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;

  const NovelCard({super.key, required this.novel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: novel.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: novel.coverUrl!,
                        width: 60,
                        height: 84,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 60, height: 84, color: Colors.grey.shade200),
                        errorWidget: (_, __, ___) => Container(
                          width: 60, height: 84, color: Colors.grey.shade200,
                          child: const Icon(Icons.book, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 60, height: 84, color: Colors.grey.shade200,
                        child: const Icon(Icons.book, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(novel.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(novel.authorName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 4),
                    if (novel.description != null)
                      Text(novel.description!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusChip(status: novel.status),
                        const SizedBox(width: 8),
                        Text(_formatWords(novel.totalWords), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWords(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}萬字';
    return '$count字';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'ongoing' => ('連載中', Colors.green),
      'completed' => ('已完結', Colors.blue),
      'hiatus' => ('暫停', Colors.orange),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
