import 'package:flutter/material.dart';

import '../data/turkey_selection_data.dart';
import '../services/profile_service.dart';
import '../widgets/searchable_selection_field.dart';

class StudentOnboardingScreen extends StatefulWidget {
  const StudentOnboardingScreen({super.key});

  @override
  State<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  final _pageController = PageController();
  final _university = TextEditingController();
  final _faculty = TextEditingController();
  final _department = TextEditingController();
  final _classYear = TextEditingController();

  static const _interests = <String>[
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

  final Set<String> _selectedInterests = {};
  int _page = 0;
  bool _newStudent2026 = true;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _university.dispose();
    _faculty.dispose();
    _department.dispose();
    _classYear.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _skip() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ProfileService.instance.completeOnboarding(skipped: true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_page == 0) {
      if (_university.text.trim().length < 3) {
        _message('Üniversiteni ara ve seç veya şimdilik geç.');
        return;
      }
      if (_department.text.trim().length < 2) {
        _message('Bölümünü yaz.');
        return;
      }
    }
    if (_page == 1 && _selectedInterests.length < 3) {
      _message('En az 3 ilgi alanı seç.');
      return;
    }
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ProfileService.instance.updateCampusProfile(
        university: _university.text,
        faculty: _faculty.text,
        department: _department.text,
        classYear: _classYear.text,
        interests: _selectedInterests.toList(),
        newStudent2026: _newStudent2026,
        showEducationOnProfile: true,
      );
      await ProfileService.instance.completeOnboarding(skipped: false);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(3, (index) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: index <= _page
                                  ? const Color(0xFFB7BCC2)
                                  : const Color(0xFF292D32),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: const Text('Şimdilik geç'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _SchoolStep(
                    university: _university,
                    faculty: _faculty,
                    department: _department,
                    classYear: _classYear,
                  ),
                  _InterestStep(
                    interests: _interests,
                    selected: _selectedInterests,
                    onToggle: (interest) => setState(() {
                      if (!_selectedInterests.add(interest)) {
                        _selectedInterests.remove(interest);
                      }
                    }),
                  ),
                  _ReadyStep(
                    university: _university.text.trim(),
                    department: _department.text.trim(),
                    newStudent2026: _newStudent2026,
                    onNewStudentChanged: (value) =>
                        setState(() => _newStudent2026 = value),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                        child: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _next,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_page == 2 ? 'Kampüsüme Git' : 'Devam'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolStep extends StatelessWidget {
  final TextEditingController university, faculty, department, classYear;
  const _SchoolStep({
    required this.university,
    required this.faculty,
    required this.department,
    required this.classYear,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
    children: [
      const Icon(Icons.school_outlined, size: 58, color: Color(0xFFB7BCC2)),
      const SizedBox(height: 20),
      const Text(
        'Kampüsünü bulalım',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text(
        'Yazmaya başla, üniversite ve fakülteni listeden seç. Sana kendi kampüsündeki toplulukları ve etkinlikleri göstereceğiz.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60, height: 1.4),
      ),
      const SizedBox(height: 30),
      SearchableSelectionField(
        controller: university,
        options: turkeyUniversities,
        labelText: 'Üniversite',
        hintText: 'Örn. Fırat Üniversitesi',
        prefixIcon: Icons.account_balance_outlined,
      ),
      const SizedBox(height: 12),
      SearchableSelectionField(
        controller: faculty,
        options: turkeyFaculties,
        labelText: 'Fakülte (isteğe bağlı)',
        hintText: 'Örn. Mühendislik Fakültesi',
        prefixIcon: Icons.apartment_outlined,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: department,
        decoration: const InputDecoration(
          labelText: 'Bölüm',
          hintText: 'Örn. Yazılım Mühendisliği',
          prefixIcon: Icon(Icons.menu_book_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: classYear,
        decoration: const InputDecoration(
          labelText: 'Sınıf (isteğe bağlı)',
          hintText: 'Hazırlık, 1, 2, 3, 4…',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
      ),
    ],
  );
}

class _InterestStep extends StatelessWidget {
  final List<String> interests;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _InterestStep({
    required this.interests,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
    children: [
      const Icon(Icons.interests_outlined, size: 58, color: Color(0xFFB7BCC2)),
      const SizedBox(height: 20),
      const Text(
        'Neler ilgini çekiyor?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        '${selected.length}/3 seçildi • En az 3 tane seç',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white60),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 9,
        runSpacing: 9,
        alignment: WrapAlignment.center,
        children: interests.map((interest) {
          return FilterChip(
            selected: selected.contains(interest),
            label: Text(interest),
            onSelected: (_) => onToggle(interest),
          );
        }).toList(),
      ),
    ],
  );
}

class _ReadyStep extends StatelessWidget {
  final String university, department;
  final bool newStudent2026;
  final ValueChanged<bool> onNewStudentChanged;
  const _ReadyStep({
    required this.university,
    required this.department,
    required this.newStudent2026,
    required this.onNewStudentChanged,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 44, 22, 24),
    children: [
      const Icon(
        Icons.rocket_launch_outlined,
        size: 64,
        color: Color(0xFFB7BCC2),
      ),
      const SizedBox(height: 22),
      const Text(
        'Hazırsın',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Text(
        university,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      if (department.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          department,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
      ],
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF121416),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF292D32)),
        ),
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: newStudent2026,
          onChanged: onNewStudentChanged,
          title: const Text('2026 yeni öğrencisiyim'),
          subtitle: const Text(
            'Yeni öğrenci etkinlikleri ve kampüs rehberi önceliklensin.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ),
    ],
  );
}
