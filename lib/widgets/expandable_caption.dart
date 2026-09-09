import 'package:flutter/material.dart';
import 'mention_text.dart';

class ExpandableCaption extends StatefulWidget {
  const ExpandableCaption({super.key, required this.text, this.style, this.mentionStyle, this.detailsInSheet = false});
  final String text;
  final TextStyle? style, mentionStyle;
  final bool detailsInSheet;
  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _expanded = false;
  @override
  void didUpdateWidget(covariant ExpandableCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  void _toggle() {
    if (!widget.detailsInSheet) { setState(() => _expanded = !_expanded); return; }
    showBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101316), showDragHandle: true,
      builder: (context) => SafeArea(top: false, child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), child: MentionText(
          text: widget.text, style: widget.style, mentionStyle: widget.mentionStyle,
        )),
      )),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style), maxLines: 1,
      textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: constraints.maxWidth);
    final hasMore = painter.didExceedMaxLines;
    painter.dispose();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MentionText(text: widget.text, style: widget.style, mentionStyle: widget.mentionStyle,
        maxLines: _expanded ? null : 1, overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis),
      if (hasMore) TextButton(
        style: TextButton.styleFrom(foregroundColor: Colors.white60, padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
        onPressed: _toggle, child: Text(_expanded ? 'Daha az göster' : 'Devamını gör'),
      ),
    ]);
  });
}

