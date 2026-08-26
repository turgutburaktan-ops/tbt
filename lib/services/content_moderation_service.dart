class ModerationResult {
  final bool blocked;
  final String? reason;

  const ModerationResult({required this.blocked, this.reason});

  static const allowed = ModerationResult(blocked: false);
}

class ContentModerationService {
  ContentModerationService._();
  static final instance = ContentModerationService._();

  static final RegExp _separator = RegExp(r'[^a-z0-9çğıöşü]+');
  static final RegExp _repeat = RegExp(r'(.)\1{2,}');

  // Keep the list focused on strong profanity / direct insults. Mild everyday
  // slang is intentionally not blocked so normal conversation is not punished.
  static const Set<String> _blockedTokens = {
    'amk',
    'aq',
    'aminakoyim',
    'aminakoyayim',
    'siktir',
    'sikik',
    'sikerim',
    'orospu',
    'orosb',
    'pic',
    'pezevenk',
    'yarrak',
    'yarak',
    'gotveren',
    'ibne',
    'kahpe',
    'kaltak',
    'oc',
    'oç',
    'orosbucocugu',
    'orospuccocugu',
  };

  static const List<String> _blockedPhrases = [
    'amina koy',
    'amina koyayim',
    'seni sikerim',
    'orospu cocugu',
    'got veren',
  ];

  String normalize(String input) {
    var value = input.toLowerCase().trim();
    const replacements = <String, String>{
      'â': 'a',
      'î': 'i',
      'û': 'u',
      '@': 'a',
      '4': 'a',
      '3': 'e',
      '1': 'i',
      '!': 'i',
      '0': 'o',
      '\$': 's',
    };
    replacements.forEach((key, replacement) {
      value = value.replaceAll(key, replacement);
    });
    value = value.replaceAll(_repeat, r'$1$1');
    return value;
  }

  ModerationResult check(String input) {
    final clean = normalize(input);
    if (clean.isEmpty) return ModerationResult.allowed;

    final phraseSource = clean.replaceAll(_separator, ' ').trim();
    for (final phrase in _blockedPhrases) {
      if (phraseSource.contains(phrase)) {
        return const ModerationResult(
          blocked: true,
          reason: 'İçeriğinde topluluk kurallarına aykırı ağır bir ifade var.',
        );
      }
    }

    final compact = clean.replaceAll(_separator, '');
    final tokens = phraseSource.split(RegExp(r'\s+'));
    for (final token in tokens) {
      if (_blockedTokens.contains(token)) {
        return const ModerationResult(
          blocked: true,
          reason: 'İçeriğinde topluluk kurallarına aykırı ağır bir ifade var.',
        );
      }
    }
    for (final blocked in _blockedTokens) {
      if (blocked.length >= 4 && compact.contains(blocked)) {
        return const ModerationResult(
          blocked: true,
          reason: 'İçeriğinde topluluk kurallarına aykırı ağır bir ifade var.',
        );
      }
    }
    return ModerationResult.allowed;
  }

  void enforce(String input) {
    final result = check(input);
    if (result.blocked) {
      throw Exception(
        result.reason ?? 'İçerik topluluk kurallarına uygun değil.',
      );
    }
  }
}
