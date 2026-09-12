import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SearchCategory {
  people('Kişiler', 'Kişi veya kullanıcı adı ara…'),
  places('Yerler', 'Gezilecek yer ara…'),
  venues('Mekânlar', 'Kafe, restoran veya işletme ara…');

  const SearchCategory(this.label, this.hint);
  final String label, hint;
}

class CategorizedSearch extends StatefulWidget {
  const CategorizedSearch({super.key, required this.resultsBuilder});
  final Widget Function(BuildContext, SearchCategory, String) resultsBuilder;

  @override
  State<CategorizedSearch> createState() => _CategorizedSearchState();
}

class _CategorizedSearchState extends State<CategorizedSearch> {
  final _controller = TextEditingController();
  SearchCategory _category = SearchCategory.people;
  String _query = '';
  Timer? _debounce;

  void _changed(String value) {
    _debounce?.cancel();
    setState(() => _query = '');
    if (value.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _select(SearchCategory category) {
    _debounce?.cancel();
    setState(() {
      _category = category;
      _query = _controller.text.trim();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          onSubmitted: (_) {
            _select(_category);
            FocusManager.instance.primaryFocus?.unfocus();
          },
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(
            hintText: _category.hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _controller.text.isEmpty ? null : IconButton(
              tooltip: 'Temizle',
              onPressed: () { _controller.clear(); _changed(''); },
              icon: const Icon(Icons.close_rounded),
            ),
            filled: true, fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.cyan)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: SearchCategory.values.map((category) => Expanded(
          child: Semantics(selected: category == _category,
            child: TextButton(
              onPressed: () => _select(category),
              style: TextButton.styleFrom(
                foregroundColor: category == _category ? AppColors.cyan : Colors.white60,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(category.label, maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Container(height: 2, color: category == _category
                    ? AppColors.cyan : Colors.transparent),
              ]),
            ),
          ),
        )).toList()),
      ),
      Expanded(child: _controller.text.trim().length < 2
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
            '${_category.label} içinde aramak için en az 2 karakter yaz.',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))))
        : _query.length < 2
          ? const Center(child: CircularProgressIndicator())
          : widget.resultsBuilder(context, _category, _query)),
    ]),
  );
}
