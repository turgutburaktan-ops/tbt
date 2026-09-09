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
    const background = Color(0xFF0D172A);
    const surface = Color(0xFF15243A);
    const accent = Color(0xFFA8CBFF);
    return Dialog(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF263B58)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flag_outlined, color: accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      labels[0],
                      style: const TextStyle(
                        color: Color(0xFFF4F7FF),
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                labels[1],
                style: const TextStyle(
                  color: Color(0xFFACBBD0),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 2; i <= 4; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        [Icons.photo_camera_outlined,
                          Icons.auto_awesome_outlined,
                          Icons.event_outlined][i - 2],
                        color: accent,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          labels[i],
                          style: const TextStyle(
                            color: Color(0xFFE8EFFA),
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${[10, 5, 15][i - 2]} XP',
                          style: const TextStyle(
                            color: accent,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 4) const SizedBox(height: 6),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFACBBD0),
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(labels[5], textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: background,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(labels[6], textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
