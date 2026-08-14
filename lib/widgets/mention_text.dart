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

  String _normalize(String value) =>
      value.trim().replaceFirst('@', '').replaceAll(' ', '').toLowerCase();

  Future<void> _openMention(String mention) async {
    final wanted = _normalize(mention);
    if (wanted.isEmpty) return;

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').limit(250).get();

      QueryDocumentSnapshot<Map<String, dynamic>>? match;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final candidates = <String>[
          (data['username'] ?? '').toString(),
          (data['displayName'] ?? '').toString(),
          (data['name'] ?? '').toString(),
        ];
        if (candidates.any((value) => _normalize(value) == wanted)) {
          match = doc;
          break;
        }
      }

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
          builder: (_) => MentionProfileScreen(userId: match!.id),
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
          color: const Color(0xFF4FD1C5),
          fontWeight: FontWeight.w800,
        );

    final spans = <TextSpan>[];
    final regex = RegExp(r'@[A-Za-z0-9_.]+');
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
