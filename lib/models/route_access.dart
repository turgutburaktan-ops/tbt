class RouteAccess {
  const RouteAccess({this.visibility = 'private', this.enabled = false,
    this.audience = 'private', this.approval = true});
  final String visibility, audience;
  final bool enabled, approval;
  static const labels = {'private': 'Davetliler', 'followers': 'Takipçilerim', 'public': 'Herkes'};
  static int rank(String value) => ['private', 'followers', 'public'].indexOf(value);
  bool get compatible => rank(visibility) >= 0 && rank(audience) >= 0 &&
      (!enabled || rank(audience) <= rank(visibility));
  Map<String, dynamic> get fields => {
    'accessVersion': 2, 'visibility': visibility, 'isPublic': visibility == 'public',
    'joinEnabled': enabled, 'joinAudience': audience,
    'joinRequiresApproval': audience != 'private' && approval,
  };
  factory RouteAccess.fromMap(Map<String, dynamic> d) => RouteAccess(
    visibility: (d['visibility'] ?? (d['isPublic'] == true ? 'public' : 'private')).toString(),
    enabled: d['joinEnabled'] == true,
    audience: (d['joinAudience'] ?? (d['joinEnabled'] == true
        ? (d['visibility'] ?? (d['isPublic'] == true ? 'public' : 'private')) : 'private')).toString(),
    approval: d['joinRequiresApproval'] != false,
  );
  String? validate(DateTime? start, {DateTime? now}) {
    if (!compatible) return 'Katılım kitlesi görünürlükten daha geniş olamaz.';
    if (enabled && (start == null || !start.isAfter(now ?? DateTime.now()))) {
      return 'Katılıma açmak için ileri bir tarih ve saat seç.';
    }
    return null;
  }
}
