class ShootingGuide {
  final String spotId;
  final String shootingPosition;
  final String subjectPlacement;
  final String lightDirection;
  final String portraitTip;
  final String compositionTip;
  final String recommendedSettings;
  final String accessibilityNote;
  final List<String> shotIdeas;

  const ShootingGuide({
    required this.spotId,
    this.shootingPosition = '',
    this.subjectPlacement = '',
    this.lightDirection = '',
    this.portraitTip = '',
    this.compositionTip = '',
    this.recommendedSettings = '',
    this.accessibilityNote = '',
    this.shotIdeas = const [],
  });

  bool get hasRichGuide =>
      shootingPosition.isNotEmpty ||
      subjectPlacement.isNotEmpty ||
      lightDirection.isNotEmpty ||
      portraitTip.isNotEmpty ||
      compositionTip.isNotEmpty ||
      recommendedSettings.isNotEmpty ||
      shotIdeas.isNotEmpty;

  factory ShootingGuide.fromMap(String spotId, Map<String, dynamic> data) {
    List<String> list(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return ShootingGuide(
      spotId: spotId,
      shootingPosition: (data['shootingPosition'] ?? '').toString().trim(),
      subjectPlacement: (data['subjectPlacement'] ?? '').toString().trim(),
      lightDirection: (data['lightDirection'] ?? '').toString().trim(),
      portraitTip: (data['portraitTip'] ?? '').toString().trim(),
      compositionTip: (data['compositionTip'] ?? '').toString().trim(),
      recommendedSettings:
          (data['recommendedSettings'] ?? '').toString().trim(),
      accessibilityNote: (data['accessibilityNote'] ?? '').toString().trim(),
      shotIdeas: list(data['shotIdeas']),
    );
  }
}
