import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../screens/mention_profile_screen.dart';

class MentionText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  String _normalize(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^@'), '')
      .replaceAll(' ', '')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i');

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUser(
    String wanted,
  ) async {
    final users = FirebaseFirestore.instance.collection('users');

    try {
      final exact = await users
          .where('usernameNormalized', isEqualTo: wanted)
          .limit(1)
          .get();
      if (exact.docs.isNotEmpty) return exact.docs.first;
    } catch (_) {
      // Eski kullanıcı kayıtlarında usernameNormalized bulunmayabilir.
    }

    final snapshot = await users.limit(300).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final candidates = <String>[
        (data['username'] ?? '').toString(),
        (data['displayName'] ?? '').toString(),
        (data['name'] ?? '').toString(),
      ];
      if (candidates.any((value) => _normalize(value) == wanted)) {
        return doc;
      }
    }
    return null;
  }

  Future<void> _openMention(String mention) async {
    final wanted = _normalize(mention);
    if (wanted.isEmpty) return;

    try {
      final match = await _findUser(wanted);
      if (!mounted) return;
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$mention kullanıcısı bulunamadı.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MentionProfileScreen(userId: match.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil açılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final mention = widget.mentionStyle ??
        base.copyWith(
          color: const Color(0xFFD7DADF),
          fontWeight: FontWeight.w800,
        );

    final spans = <TextSpan>[];
    final regex = RegExp(
      r'@[\p{L}\p{N}_.]+',
      unicode: true,
    );
    var cursor = 0;
    for (final match in regex.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openMention(token);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: token, style: mention, recognizer: recognizer));
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
