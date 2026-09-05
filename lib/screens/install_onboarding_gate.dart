import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallOnboardingGate extends StatefulWidget {
  final Widget child;
  const InstallOnboardingGate({super.key, required this.child});

  @override
  State<InstallOnboardingGate> createState() => _InstallOnboardingGateState();
}

class _InstallOnboardingGateState extends State<InstallOnboardingGate> {
  bool? _completed;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _completed = prefs.getBool('install_intro_completed') == true);
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('install_intro_completed', true);
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_completed == true) return widget.child;
    return _InstallIntro(onFinished: _finish);
  }
}

class _InstallIntro extends StatefulWidget {
  final Future<void> Function() onFinished;
  const _InstallIntro({required this.onFinished});

  @override
  State<_InstallIntro> createState() => _InstallIntroState();
}

class _InstallIntroState extends State<_InstallIntro> {
  final _controller = PageController();
  int _page = 0;
  static const _pages = [
    (Icons.explore_rounded, 'TBT ile keşfet', 'Gezilecek yerleri, mekanları ve topluluğun paylaştığı deneyimleri tek yerde bul.'),
    (Icons.route_rounded, 'Rotanı akıllı planla', 'Şehrine ve ilgi alanlarına göre rota oluştur; yakınındaki önerileri gör.'),
    (Icons.groups_rounded, 'Paylaş ve katıl', 'Fotoğraf ve video paylaş, etkinliklere katıl, kampanya ve kuponları kullan.'),
  ];

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF090A0C),
    body: SafeArea(
      child: Column(
        children: [
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: widget.onFinished, child: const Text('Atla'))),
          Expanded(child: PageView.builder(controller: _controller, itemCount: _pages.length, onPageChanged: (value) => setState(() => _page = value), itemBuilder: (_, index) { final item = _pages[index]; return Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 112, height: 112, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00BDD6), Color(0xFF7257FF)]), borderRadius: BorderRadius.circular(34)), child: Icon(item.$1, size: 58, color: Colors.white)), const SizedBox(height: 34), Text(item.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 14), Text(item.$3, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 16, height: 1.5))])); })),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (index) => AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.all(4), width: index == _page ? 24 : 8, height: 8, decoration: BoxDecoration(color: index == _page ? const Color(0xFF55E0D2) : Colors.white24, borderRadius: BorderRadius.circular(9))))),
          Padding(padding: const EdgeInsets.all(24), child: SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: () { if (_page == _pages.length - 1) { widget.onFinished(); } else { _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut); } }, child: Text(_page == _pages.length - 1 ? 'TBT’yi Keşfet' : 'Devam Et')))),
        ],
      ),
    ),
  );
}
