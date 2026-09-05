import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses the same Turkey calendar day as the server's daily XP accounting.
String dailyGoalsDayKey(DateTime time) {
  final day = time.toUtc().add(const Duration(hours: 3));
  return '${day.year}${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';
}

class DailyGoalsPrompt extends StatefulWidget {
  final String userId;
  final Widget child;
  const DailyGoalsPrompt({super.key, required this.userId, required this.child});

  @override
  State<DailyGoalsPrompt> createState() => _DailyGoalsPromptState();
}

class _DailyGoalsPromptState extends State<DailyGoalsPrompt>
    with WidgetsBindingObserver {
  bool _checking = false;
  String? _shownDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;
    final day = dailyGoalsDayKey(DateTime.now());
    if (_shownDay == day) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'daily_goals_shown_${widget.userId}';
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != widget.userId ||
          prefs.getString(key) == day) return;
      _shownDay = day;
      final dialog = showDialog<bool>(
        context: context,
        builder: (context) => const _DailyGoalsDialog(),
      );
      // Persist on presentation, so dismiss/back/restart does not repeat it.
      await prefs.setString(key, day);
      final openGoals = await dialog;
      if (openGoals == true && mounted &&
          FirebaseAuth.instance.currentUser?.uid == widget.userId) {
        await Navigator.of(context).pushNamed('/rewards');
      }
    } catch (error) {
      // An optional reminder must never prevent entry to the app.
      debugPrint('Daily goals prompt unavailable: ${error.runtimeType}');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DailyGoalsDialog extends StatelessWidget {
  const _DailyGoalsDialog();

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final labels = switch (code) {
      'en' => ['Today’s goals', 'Make room for a new experience today.',
        'Share a post', 'Share a Story', 'Join an event', 'Later', 'View goals'],
      'de' => ['Deine Tagesziele', 'Entdecke heute etwas Neues.',
        'Beitrag teilen', 'Story teilen', 'An einem Event teilnehmen', 'Später', 'Ziele ansehen'],
      'ar' => ['أهداف اليوم', 'اكتشف تجربة جديدة اليوم.',
        'شارك منشوراً', 'شارك قصة', 'انضم إلى فعالية', 'لاحقاً', 'عرض الأهداف'],
      _ => ['Bugünkü hedeflerin', 'Bugün yeni bir deneyime yer aç.',
        'Bir paylaşım yap', 'Bir Story paylaş', 'Bir etkinliğe katıl', 'Daha sonra', 'Hedefleri gör'],
    };
    return AlertDialog(
      icon: const Icon(Icons.flag_rounded, color: Color(0xFF55E0D2), size: 36),
      title: Text(labels[0]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(labels[1]),
            const SizedBox(height: 16),
            for (var i = 2; i <= 4; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon([Icons.photo_camera_outlined,
                  Icons.auto_awesome_outlined, Icons.event_outlined][i - 2]),
                title: Text(labels[i]),
                trailing: Text('+${[10, 5, 15][i - 2]} XP'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(labels[5])),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(labels[6])),
      ],
    );
  }
}
