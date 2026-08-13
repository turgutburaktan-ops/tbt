from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Track the last AI adjustment so users can see that values really changed.
    if 'DateTime? _lastAiAppliedAt;' not in text:
        marker = '  DateTime? _lastAiAnalysisAt;\n'
        text = text.replace(
            marker,
            marker + "  DateTime? _lastAiAppliedAt;\n  String _lastAiAppliedSummary = 'AI hazır';\n",
            1,
        )

    # Capture the previous values at the beginning of every AI decision.
    ai_marker = "  Future<void> _applyAiDecision() async {\n"
    if ai_marker in text and 'final previousIso = _currentIso;' not in text:
        text = text.replace(
            ai_marker,
            ai_marker
            + "    final previousIso = _currentIso;\n"
            + "    final previousShutter = _currentShutter;\n"
            + "    final previousEv = _currentEv;\n\n",
            1,
        )

    # Update the visible HUD only after the native sensor exposure has been applied.
    old_state = """      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
      });
"""
    new_state = """      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _lastAiAppliedAt = DateTime.now();

        final changes = <String>[];
        if (previousIso != iso) changes.add('ISO $previousIso→$iso');
        if (previousShutter != shutter) {
          final oldUs = previousShutter.inMicroseconds;
          final newUs = shutter.inMicroseconds;
          final oldS = oldUs >= 1000000
              ? '${(oldUs / 1000000).toStringAsFixed(1)}s'
              : '1/${max(1, (1000000 / oldUs).round())}';
          final newS = newUs >= 1000000
              ? '${(newUs / 1000000).toStringAsFixed(1)}s'
              : '1/${max(1, (1000000 / newUs).round())}';
          changes.add('S $oldS→$newS');
        }
        if ((previousEv - ev).abs() >= 0.05) {
          final oldEv = '${previousEv >= 0 ? '+' : ''}${previousEv.toStringAsFixed(1)}';
          final newEv = '${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)}';
          changes.add('EV $oldEv→$newEv');
        }
        _lastAiAppliedSummary = changes.isEmpty
            ? 'Sahne dengede • ayar korunuyor'
            : changes.join('  •  ');
      });
"""
    # Replace only the state block inside _applyAiDecision.
    ai_pos = text.find(ai_marker)
    if ai_pos >= 0 and '_lastAiAppliedAt = DateTime.now();' not in text[ai_pos:ai_pos + 12000]:
        state_pos = text.find(old_state, ai_pos)
        if state_pos >= 0:
            text = text[:state_pos] + new_state + text[state_pos + len(old_state):]

    # Replace the compact parameter strip with a live, readable AI sensor HUD.
    start = text.find('  Widget _buildCameraParams() {')
    end = text.find('  Widget _buildModes() {', start)
    if start >= 0 and end > start and 'AI LIVE • SENSÖRE UYGULANDI' not in text[start:end]:
        new_widget = '''  Widget _buildCameraParams() {
    final justApplied = _lastAiAppliedAt != null &&
        DateTime.now().difference(_lastAiAppliedAt!) < const Duration(seconds: 3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 68,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: justApplied ? const Color(0x66FFC107) : Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _aiBusy
                      ? Colors.orangeAccent
                      : const Color(0xFFFFC107),
                  boxShadow: justApplied
                      ? const [
                          BoxShadow(
                            color: Color(0x99FFC107),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _aiBusy ? 'AI SAHNEYİ ANALİZ EDİYOR' : 'AI LIVE • SENSÖRE UYGULANDI',
                style: const TextStyle(
                  color: Color(0xFFFFC107),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .25,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _aiBusy ? 'Yeni ayar hesaplanıyor…' : _lastAiAppliedSummary,
                    key: ValueKey('${_lastAiAppliedSummary}_${_aiBusy}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Param(label: 'ISO', value: '$_currentIso'),
                _Param(label: 'S', value: _shutterHud),
                _Param(label: 'ODAK', value: _currentFocus),
                _Param(label: 'WB', value: _currentWb),
                _Param(
                  label: 'EV',
                  value: '${_currentEv >= 0 ? '+' : ''}${_currentEv.toStringAsFixed(1)}',
                  accent: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

'''
        text = text[:start] + new_widget + text[end:]

    # Animate the numeric values themselves when AI changes them.
    old_value = '''        Text(
          value,
          style: TextStyle(
            color: accent ? const Color(0xFFFFC107) : Colors.white,
            fontSize: 11,
'''
    if old_value in text and 'ValueKey(value)' not in text[text.find('class _Param'):]:
        new_value = '''        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: .82, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              color: accent ? const Color(0xFFFFC107) : Colors.white,
              fontSize: 11,
'''
        text = text.replace(old_value, new_value, 1)
        # Close AnimatedSwitcher after the existing Text widget.
        target = '''            fontWeight: FontWeight.w800,
          ),
        ),
'''
        replacement = '''              fontWeight: FontWeight.w800,
            ),
          ),
        ),
'''
        param_pos = text.find('class _Param')
        close_pos = text.find(target, param_pos)
        if close_pos >= 0:
            text = text[:close_pos] + replacement + text[close_pos + len(target):]

    path.write_text(text)
    print('Live AI HUD patch applied: animated ISO/shutter/EV + native sensor status')


if __name__ == '__main__':
    main()
