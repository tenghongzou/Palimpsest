import '../../../core/l10n/l10n.dart';

/// Labels for the API's novel sort orders, rankings and statuses.

String novelSortLabel(String key, AppLocalizations l) => switch (key) {
      'latest' => l.sortLatest,
      'popular' => l.sortPopular,
      'rating' => l.sortRating,
      'words' => l.sortWords,
      'favorites' => l.sortFavorites,
      'new' => l.sortNew,
      _ => key,
    };

String rankingTypeLabel(String type, AppLocalizations l) => switch (type) {
      'views' => l.rankingViews,
      'favorites' => l.rankingFavorites,
      'rating' => l.rankingRating,
      'latest' => l.rankingLatest,
      'completed' => l.rankingCompleted,
      _ => type,
    };

String rankingPeriodLabel(String period, AppLocalizations l) => switch (period) {
      'daily' => l.periodDaily,
      'weekly' => l.periodWeekly,
      'monthly' => l.periodMonthly,
      'all' => l.periodAll,
      _ => period,
    };

/// A novel status (`ongoing`, `completed`, `hiatus`); null means any.
String novelStatusLabel(String? status, AppLocalizations l) => switch (status) {
      null => l.statusAll,
      'ongoing' => l.statusOngoing,
      'completed' => l.statusCompleted,
      'hiatus' => l.statusHiatus,
      _ => status,
    };
