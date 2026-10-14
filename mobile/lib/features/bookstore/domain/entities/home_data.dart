import 'novel.dart';

class HomeBanner {
  final String id;
  final String title;
  final String imageUrl;

  /// novel, url or category.
  final String? linkType;
  final String? linkValue;

  const HomeBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.linkType,
    this.linkValue,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        linkType: json['link_type'] as String?,
        linkValue: json['link_value'] as String?,
      );
}

/// Sections of `GET /home`.
class HomeData {
  final List<HomeBanner> banners;
  final List<Novel> featured;
  final List<Novel> latestUpdates;
  final List<Novel> popular;
  final List<Novel> newArrivals;
  final List<Novel> completed;

  const HomeData({
    this.banners = const [],
    this.featured = const [],
    this.latestUpdates = const [],
    this.popular = const [],
    this.newArrivals = const [],
    this.completed = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    List<Novel> novels(String key) =>
        (json[key] as List? ?? const []).map((e) => Novel.fromJson(e as Map<String, dynamic>)).toList();
    return HomeData(
      banners: (json['banners'] as List? ?? const [])
          .map((e) => HomeBanner.fromJson(e as Map<String, dynamic>))
          .toList(),
      featured: novels('featured'),
      latestUpdates: novels('latest_updates'),
      popular: novels('popular'),
      newArrivals: novels('new_arrivals'),
      completed: novels('completed'),
    );
  }
}
