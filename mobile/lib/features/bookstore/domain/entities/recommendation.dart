import 'novel.dart';

/// Why a novel is recommended (`RecommendationReason`); the client phrases
/// it in the UI language.
enum RecommendationReasonType {
  /// [RecommendationReason.value] is a category name.
  category,

  /// [RecommendationReason.value] is a tag name.
  tag,

  /// [RecommendationReason.value] is the author's name.
  author,

  /// A popular novel; no value.
  popular;

  /// Unknown types (a newer server) read as [popular].
  static RecommendationReasonType parse(Object? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => popular);
}

class RecommendationReason {
  final RecommendationReasonType type;
  final String value;

  const RecommendationReason(this.type, [this.value = '']);

  factory RecommendationReason.fromJson(Map<String, dynamic>? json) {
    final type = RecommendationReasonType.parse(json?['type']);
    final value = (json?['value'] as String? ?? '').trim();
    // A named reason without its name says nothing; show it as popular.
    if (type != RecommendationReasonType.popular && value.isEmpty) {
      return const RecommendationReason(RecommendationReasonType.popular);
    }
    return RecommendationReason(type, value);
  }
}

class Recommendation {
  final Novel novel;
  final RecommendationReason reason;

  const Recommendation({required this.novel, required this.reason});

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        novel: Novel.fromJson(json['novel'] as Map<String, dynamic>),
        reason: RecommendationReason.fromJson(json['reason'] as Map<String, dynamic>?),
      );
}

/// `GET /recommendations`: [personalized] is false when [items] are popular
/// novels (signed out, or no reading signals yet).
class Recommendations {
  final bool personalized;
  final List<Recommendation> items;

  const Recommendations({this.personalized = false, this.items = const []});

  factory Recommendations.fromJson(Map<String, dynamic> json) => Recommendations(
        personalized: json['personalized'] as bool? ?? false,
        items: (json['items'] as List? ?? const [])
            .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
