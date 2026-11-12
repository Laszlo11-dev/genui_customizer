import 'models.dart';

/// Conservative politics/war filter for a technology reader. A broad `Policy`
/// category is deliberately insufficient: it also includes tech regulation.
bool isPoliticalNews(NewsItem item) {
  for (final category in item.categories) {
    final tag = category.toLowerCase().trim();
    if (_politicalTags.contains(tag) || _politicalTagPattern.hasMatch(tag)) {
      return true;
    }
  }
  // Many RSS/Atom feeds omit categories, so catch clear signals in the title.
  // We avoid the summary because it often mentions a politician incidentally.
  return _politicalTitlePattern.hasMatch(item.title);
}

const _politicalTags = <String>{
  'politics',
  'political news',
  'elections',
  'election',
  'donald trump',
  'trump administration',
  'joe biden',
  'vladimir putin',
  'ukraine war',
  'usa-iran war',
  'iran war',
};

final _politicalTagPattern = RegExp(
  r'\b(war on ukraine|invasion of ukraine|trump.*war|presidential election|parliamentary election)\b',
  caseSensitive: false,
);

final _politicalTitlePattern = RegExp(
  r'\b(trump|biden|putin|zelensky|election|congress|parliament|invasion|war|drone strikes|russian strikes)\b',
  caseSensitive: false,
);
