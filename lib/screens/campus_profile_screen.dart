import 'package:flutter/material.dart';

import '../data/turkey_selection_data.dart';
import '../services/profile_service.dart';
import '../widgets/searchable_selection_field.dart';

class CampusProfileScreen extends StatefulWidget {
  const CampusProfileScreen({super.key});

  @override
  State<CampusProfileScreen> createState() => _CampusProfileScreenState();
}

class _CampusProfileScreenState extends State<CampusProfileScreen> {
  final _university = TextEditingController();
  final _faculty = TextEditingController();
  final _department = TextEditingController();

  String? _studentStatus;
  String? _classYear;

  static const _classYears = <String>[
    'Hazırlık',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    'Mezun',
  ];

  static const _allInterests = <String>[
    'Fotoğraf',
    'Kamp',
    'Yürüyüş',
    'Kahve',
    'Gezi',
    'Spor',
    'Oyun',
    'Müzik',
    'Sanat',
    'Yemek',
    'Teknoloji',
    'Sinema',
  ];

  final Set<String> _interests = {};
  bool _newStudent2026 = false;
  bool _showEducation = true;
  bool _saving = false;

  bool get _isStudent => _studentStatus == 'student';
  bool get _graduate => _isStudent && _classYear == 'Mezun';

  @override
  void dispose() {
    _university.dispose();
    _faculty.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_studentStatus == null) {
      _message('Öğrenci durumunu seçmelisin.');
      return;
    }

    if (!_isStudent) {
      setState(() => _saving = true);
      try {
        await ProfileService.instance.updateStudentStatus(
          status: 'non_student',
        );
        if (!mounted) return;
        _message('Öğrenci durumu kaydedildi. Kampüs sekmesi kapalı kalacak.');
        Navigator.pop(context, true);
      } catch (e) {
        _message(e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    if (_university.text.trim().isEmpty || _department.text.trim().isEmpty) {
      _message('Üniversite ve bölüm bilgisi gerekli.');
      return;
    }
    if (_classYear == null || _classYear!.isEmpty) {
      _message('Sınıfını seçmelisin.');
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
        classYear: _classYear ?? '',
        interests: _interests.toList(),
        newStudent2026: _newStudent2026,
        showEducationOnProfile: _showEducation,
      );
      if (!mounted) return;
      _message(
        _graduate
            ? 'Eğitim bilgin kaydedildi. Mezun hesaplarda Kampüs kapalıdır.'
            : 'Kampüs profilin kaydedildi.',
      );
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

  String _classLabel(String value) {
    if (value == 'Hazırlık' || value == 'Mezun') return value;
    return '$value. Sınıf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: const Text('Öğrenci / Kampüs Bilgileri'),
        actions: [
          IconButton(
            tooltip: 'Topluluklar',
            onPressed: _isStudent && !_graduate
                ? () => Navigator.pushNamed(context, '/communities')
                : null,
            icon: const Icon(Icons.groups_2_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const Text(
            'Kampüs yalnız aktif üniversite öğrencilerine görünür. Öğrenci durumunu buradan belirleyebilirsin.',
            style: TextStyle(color: Colors.white60, height: 1.45),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _studentStatus,
            decoration: const InputDecoration(
              labelText: 'Öğrenci durumu',
              hintText: 'Durumunu seç',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'student',
                child: Text('Üniversite öğrencisiyim'),
              ),
              DropdownMenuItem(
                value: 'non_student',
                child: Text('Öğrenci değilim'),
              ),
            ],
            onChanged: (value) => setState(() {
              _studentStatus = value;
              if (value != 'student') {
                _classYear = null;
                _newStudent2026 = false;
              }
            }),
          ),
          if (_isStudent) ...[
            const SizedBox(height: 16),
            SearchableSelectionField(
              controller: _university,
              options: turkeyUniversities,
              labelText: 'Üniversite',
              hintText: 'Yazmaya başla ve seç',
              prefixIcon: Icons.school_outlined,
            ),
            const SizedBox(height: 12),
            SearchableSelectionField(
              controller: _faculty,
              options: turkeyFaculties,
              labelText: 'Fakülte',
              hintText: 'Yazmaya başla ve seç',
              prefixIcon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _department,
              decoration: const InputDecoration(
                labelText: 'Bölüm',
                hintText: 'Örn. Yazılım Mühendisliği',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _classYear,
              decoration: const InputDecoration(
                labelText: 'Sınıf',
                hintText: 'Sınıfını seç',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: _classYears
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_classLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _classYear = value),
            ),
            if (_graduate) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121416),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Colors.white54),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mezun seçildiğinde Kampüs sekmesi görünmez ve Kampüs alanı kapalı kalır.',
                        style: TextStyle(color: Colors.white60, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            const Text(
              'Nelerden hoşlanıyorsun?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'En az 3 seçim yap.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
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
              onChanged: _graduate
                  ? null
                  : (v) => setState(() => _newStudent2026 = v),
              title: const Text('2026 yeni öğrencisiyim'),
              subtitle: const Text(
                'Yeni öğrenci etkinlikleri ve kampüs rehberi önceliklensin.',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _showEducation,
              onChanged: (v) => setState(() => _showEducation = v),
              title: const Text('Eğitim bilgilerimi profilimde göster'),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
