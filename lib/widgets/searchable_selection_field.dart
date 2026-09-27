import 'package:flutter/material.dart';

class SearchableSelectionField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> options;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;
  final int maxSuggestions;
  final bool enabled;

  const SearchableSelectionField({
    super.key,
    required this.controller,
    required this.options,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.onChanged,
    this.onSelected,
    this.maxSuggestions = 8,
    this.enabled = true,
  });

  @override
  State<SearchableSelectionField> createState() =>
      _SearchableSelectionFieldState();
}

class _SearchableSelectionFieldState extends State<SearchableSelectionField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  Iterable<String> _matches(TextEditingValue value) {
    final query = _normalize(value.text);
    if (query.isEmpty) return widget.options.take(widget.maxSuggestions);

    final starts = <String>[];
    final contains = <String>[];
    for (final option in widget.options) {
      final normalized = _normalize(option);
      if (normalized.startsWith(query)) {
        starts.add(option);
      } else if (normalized.contains(query)) {
        contains.add(option);
      }
    }
    return [...starts, ...contains].take(widget.maxSuggestions);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option,
      optionsBuilder: _matches,
      onSelected: (selection) {
        widget.onChanged?.call(selection);
        widget.onSelected?.call(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          onChanged: (value) {
            widget.onChanged?.call(value);
            setState(() {});
          },
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon),
            suffixIcon: focusNode.hasFocus && controller.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.close_rounded, size: 19),
                    onPressed: () {
                      controller.clear();
                      widget.onChanged?.call('');
                      setState(() {});
                    },
                  )
                : IconButton(
                    tooltip: 'Listeyi aç',
                    onPressed: widget.enabled
                        ? () {
                            focusNode.requestFocus();
                            controller.notifyListeners();
                          }
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList(growable: false);
        if (items.isEmpty) return const SizedBox.shrink();
        final width = MediaQuery.sizeOf(context).width - 36;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: const Color(0xFF171A1E),
            elevation: 12,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 280,
                maxWidth: width,
                minWidth: width,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, index) {
                  final option = items[index];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.prefixIcon ?? Icons.search_rounded,
                            size: 18,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.north_west_rounded,
                            size: 16,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
