/// Copy route content without carrying event dates, participants or private data.
Map<String, dynamic> copyRouteDayPlan(Map<String, dynamic> source) => {
  for (final key in const [
    'routeVersion',
    'signature',
    'manual',
    'roundTrip',
    'geometry',
    'legs',
    'description',
    'difficulty',
    'difficultyEstimated',
    'returnIncluded',
    'originLatitude',
    'originLongitude',
  ])
    if (source.containsKey(key)) key: source[key],
};

bool canSuggestRouteStop(Map<String, dynamic> stop) =>
    ((stop['id'] ?? '').toString().startsWith('custom_') ||
        (stop['id'] ?? '').toString().startsWith('map:')) &&
    stop['venue'] is! Map;
