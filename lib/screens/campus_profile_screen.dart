import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class CampusProfileScreen extends StatefulWidget {
  const CampusProfileScreen({super.key});

  @override
  State<CampusProfileScreen> createState() => _CampusProfileScreenState();
}

class _CampusProfileScreenState extends State<CampusProfileScreen> {
  final _university = TextEditingController();
  final _faculty = TextEditingController();
  final _department = TextEditingController();
  final _classYear = TextEditingController();

  static const _allInterests = <String>[
    'Fotoğraf', 'Kamp', 'Yürüyüş', 'Kahve', 'Gezi', 'Spor',
    'Oyun', 'Müzik', 'Sanat', 'Yemek', 'Teknoloji', 'Sinema',
  ];

  final Set<String> _interests = {};
  bool _newStudent2026 = false;
  bool _showEducation = true;
  bool _saving = false;

  @override
  void dispose() {
    _university.dispose();
    _faculty.dispose();
    _department.dispose();
    _classYear.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_university.text.trim().isEmpty || _department.text.trim().isEmpty) {
      _message('Üniversite ve bölüm bilgisi gerekli.');
      return;
    }
    if (_interests.length < 3) {
      _message('Sana daha iyi öneriler sunmak için en az 3 ilgi alanı seç.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ProfileService.instance.updateCampusProfile(
        university: _university.text,
        faculty: _faculty.text,
        department: _department.text,
        classYear: _classYear.text,
        interests: _interests.toList(),
        newStudent2026: _newStudent2026,
        showEducationOnProfile: _showEducation,
      );
      if (!mounted) return;
      _message('Kampüs profilin kaydedildi.');
      Navigator.pop(context, true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0C), title: const Text('Kampüs Profilim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const Text(
            'Üniversitendeki toplulukları, etkinlikleri ve sana uygun keşifleri gösterebilmemiz için birkaç bilgi ekle.',
            style: TextStyle(color: Colors.white60, height: 1.45),
          ),
          const SizedBox(height: 20),
          TextField(controller: _university, decoration: const InputDecoration(labelText: 'Üniversite', hintText: 'Örn. Fırat Üniversitesi', prefixIcon: Icon(Icons.school_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _faculty, decoration: const InputDecoration(labelText: 'Fakülte', hintText: 'Örn. Mühendislik Fakültesi', prefixIcon: Icon(Icons.account_balance_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _department, decoration: const InputDecoration(labelText: 'Bölüm', hintText: 'Örn. Yazılım Mühendisliği', prefixIcon: Icon(Icons.menu_book_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _classYear, decoration: const InputDecoration(labelText: 'Sınıf', hintText: 'Hazırlık, 1, 2, 3, 4…', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 22),
          const Text('Nelerden hoşlanıyorsun?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('En az 3 seçim yap.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allInterests.map((interest) {
              final selected = _interests.contains(interest);
              return FilterChip(
                selected: selected,
                label: Text(interest),
                onSelected: (_) => setState(() {
                  if (selected) {
                    _interests.remove(interest);
                  } else {
                    _interests.add(interest);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _newStudent2026,
            onChanged: (v) => setState(() => _newStudent2026 = v),
            title: const Text('2026 yeni öğrencisiyim'),
            subtitle: const Text('Yeni öğrenci etkinlikleri ve kampüs rehberi önceliklensin.'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _showEducation,
            onChanged: (v) => setState(() => _showEducation = v),
            title: const Text('Eğitim bilgilerimi profilimde göster'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet ve Devam Et'),
            ),
          ),
        ],
      ),
    );
  }
}
