import '../i18n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme.dart';
import '../gsi.dart';
import '../tools_state.dart';
import '../widgets.dart';

String mmss(int sec) {
  final neg = sec < 0;
  final s = sec.abs();
  return '${neg ? '−' : ''}${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Таймеры матча: руны, стаки, Рошан, Торментор, день и ночь — с голосом и вибрацией.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _OneShot {
  final String title;
  final int at;
  final int lead;
  const _OneShot(this.title, this.at, this.lead);
}

class _TimerScreenState extends State<TimerScreen> {
  final FlutterTts tts = FlutterTts();
  Timer? ticker;
  DateTime? startedAt; // когда в реальном времени было «0:00» игры
  int pausedAt = 0; // игровое время в момент паузы
  bool running = false;
  final Set<String> fired = {};
  final List<_OneShot> oneShots = [];

  int get now => running && startedAt != null ? DateTime.now().difference(startedAt!).inSeconds : pausedAt;

  @override
  void initState() {
    super.initState();
    tts.setLanguage(isEn ? 'en-US' : 'ru-RU');
    tts.setSpeechRate(0.55);
    ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void dispose() {
    ticker?.cancel();
    tts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  void _say(String text) {
    if (ToolsScope.read(context).voice) tts.speak(text);
  }

  void _start({int at = 0}) {
    setState(() {
      startedAt = DateTime.now().subtract(Duration(seconds: at));
      running = true;
      fired.clear();
    });
    WakelockPlus.enable();
  }

  void _pause() {
    if (!running) {
      _start(at: pausedAt);
      return;
    }
    setState(() {
      pausedAt = now;
      running = false;
    });
  }

  void _reset() {
    setState(() {
      running = false;
      startedAt = null;
      pausedAt = 0;
      fired.clear();
      oneShots.clear();
    });
    WakelockPlus.disable();
  }

  Future<void> _setTime() async {
    final m = TextEditingController(), s = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(L('Сколько сейчас в игре?', 'What is the game time now?'), style: T.h2),
        content: Row(children: [
          Expanded(child: TextField(controller: m, keyboardType: TextInputType.number, decoration: fieldDeco(L('мин', 'min')))),
          Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: T.h2)),
          Expanded(child: TextField(controller: s, keyboardType: TextInputType.number, decoration: fieldDeco(L('сек', 'sec')))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Старт', 'Start'))),
        ],
      ),
    );
    final at = (int.tryParse(m.text) ?? 0) * 60 + (int.tryParse(s.text) ?? 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      m.dispose();
      s.dispose();
    });
    if (ok == true) {
      _start(at: at);
      // События, которые уже прошли, не объявляем.
      for (final e in ToolsScope.read(context).timerEvents) {
        for (var t = e.first; t <= at && (e.every > 0 || t == e.first); t += e.every > 0 ? e.every : 1 << 30) {
          fired.add('${e.id}@$t');
          fired.add('${e.id}@$t-lead');
        }
      }
    }
  }

  void _addOneShots(List<_OneShot> list) {
    if (!running) {
      showToast(context, L('Сначала запусти таймер', 'Start the timer first'));
      return;
    }
    setState(() => oneShots.addAll(list));
    HapticFeedback.mediumImpact();
  }

  void _tick() {
    if (!mounted) return;
    // Если Dota присылает время матча (GSI) — часы идут сами.
    final g = gsi.last;
    if (gsi.live && g != null && g.clock != null && g.inGame) {
      final target = DateTime.now().subtract(Duration(seconds: g.clock!));
      if (!running || startedAt == null || startedAt!.difference(target).inSeconds.abs() > 1) {
        startedAt = target;
        if (!running) WakelockPlus.enable();
        running = true;
      }
    }
    if (!running) return;
    final t = now;
    final events = ToolsScope.read(context).timerEvents.where((e) => e.enabled);
    for (final e in events) {
      final next = e.nextAt(t);
      if (next == null) continue;
      if (e.lead > 0 && t == next - e.lead && fired.add('${e.id}@$next-lead')) {
        _say(L('Через ${e.lead} секунд — ${e.title.toLowerCase()}', 'In ${e.lead} seconds — ${e.title.toLowerCase()}'));
      }
      if (t == next && fired.add('${e.id}@$next')) {
        HapticFeedback.heavyImpact();
        _say(e.title);
      }
    }
    for (final o in oneShots) {
      if (o.lead > 0 && t == o.at - o.lead && fired.add('${o.title}@${o.at}-lead')) {
        _say(L('Через ${o.lead} секунд — ${o.title.toLowerCase()}', 'In ${o.lead} seconds — ${o.title.toLowerCase()}'));
      }
      if (t == o.at && fired.add('${o.title}@${o.at}')) {
        HapticFeedback.heavyImpact();
        _say(o.title);
      }
    }
    oneShots.removeWhere((o) => o.at < t - 30);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    final t = now;
    final upcoming = <(String, int)>[];
    for (final e in tools.timerEvents.where((e) => e.enabled)) {
      final n = e.nextAt(t);
      if (n != null) upcoming.add((e.title, n));
    }
    for (final o in oneShots) {
      if (o.at >= t) upcoming.add((o.title, o.at));
    }
    upcoming.sort((a, b) => a.$2.compareTo(b.$2));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Таймеры матча', 'Match timers'), style: T.h2),
        actions: [
          IconButton(
            tooltip: L('Голос', 'Voice'),
            icon: Icon(tools.voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
            onPressed: () => tools.setVoice(!tools.voice),
          ),
          IconButton(
            tooltip: L('Настроить тайминги', 'Edit timings'),
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimerSettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          AppCard(
            child: Column(children: [
              Text(mmss(t), style: T.num(56, color: running ? C.text : C.muted)),
              const SizedBox(height: 4),
              Text(running ? gsi.live ? L('синхронизировано с Dota', 'synced with Dota') : L('идёт игра', 'game running') : (startedAt == null ? L('нажми «Старт» вместе с горном 0:00', 'tap Start together with the 0:00 horn') : L('пауза', 'paused')),
                  style: T.small),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size(0, 46)),
                    onPressed: startedAt == null ? () => _start() : _pause,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(startedAt == null ? L('Старт 0:00', 'Start 0:00') : (running ? L('Пауза', 'Pause') : L('Продолжить', 'Resume'))),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: BorderSide(color: C.border)),
                  onPressed: _setTime,
                  child: Text(L('Задать время', 'Set time')),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _reset, icon: Icon(Icons.restart_alt, color: C.muted)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _bigBtn(L('Рошан убит', 'Roshan killed'), Icons.whatshot, C.gold, () {
                _addOneShots([
                  _OneShot(L('Аегис пропадает', 'Aegis expires'), t + 300, 30),
                  _OneShot(L('Рошан может возродиться', 'Roshan may respawn'), t + 480, 20),
                  _OneShot(L('Рошан точно возродился', 'Roshan has respawned'), t + 660, 0),
                ]);
                showToast(context, L('Аегис до ${mmss(t + 300)}, Рошан с ${mmss(t + 480)} до ${mmss(t + 660)}', 'Aegis until ${mmss(t + 300)}, Roshan between ${mmss(t + 480)} and ${mmss(t + 660)}'));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _bigBtn(L('Торментор убит', 'Tormentor killed'), Icons.diamond_outlined, C.intel, () {
                _addOneShots([_OneShot(L('Торментор возродился', 'Tormentor respawned'), t + 600, 20)]);
                showToast(context, L('Торментор вернётся в ${mmss(t + 600)}', 'Tormentor returns at ${mmss(t + 600)}'));
              }),
            ),
          ]),
          SectionLabel(L('Ближайшие события', 'Upcoming events')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              if (upcoming.isEmpty)
                Padding(padding: EdgeInsets.all(14), child: Text(L('Нет включённых таймеров.', 'No timers enabled.'), style: T.small)),
              for (final u in upcoming.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(u.$1, style: T.body)),
                    Text(mmss(u.$2), style: T.num(14, color: C.muted)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 56,
                      child: Text(L('через ${mmss(u.$2 - t)}', 'in ${mmss(u.$2 - t)}'),
                          textAlign: TextAlign.right,
                          style: T.small.copyWith(color: u.$2 - t <= 20 ? C.gold : C.muted)),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            L('Экран не гаснет, пока таймер запущен. Если матч уже идёт — нажми «Задать время» и введи время с игровых часов. '
            'Тайминги можно поменять в настройках (иконка вверху), если в новом патче они изменятся.', 'The screen stays on while the timer runs. If the match is already going, tap Set time and enter the game clock. '
            'Timings can be changed in settings (icon at the top) if a new patch changes them.'),
            style: T.small,
          ),
        ],
      ),
    );
  }

  Widget _bigBtn(String text, IconData icon, Color color, VoidCallback onTap) => AppCard(
        onTap: onTap,
        borderColor: color.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(text, style: T.body.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Включение и правка таймингов.
class TimerSettingsScreen extends StatelessWidget {
  const TimerSettingsScreen({super.key});

  Future<void> _edit(BuildContext context, ToolsState tools, TimerEvent e) async {
    final first = TextEditingController(text: mmss(e.first));
    final every = TextEditingController(text: e.every == 0 ? '' : mmss(e.every));
    final lead = TextEditingController(text: '${e.lead}');
    int? parse(String s) {
      final p = s.trim().split(':');
      if (p.length == 2) return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
      return int.tryParse(s.trim());
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(e.title, style: T.h2),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: first, decoration: fieldDeco(L('Первый раз (мм:сс)', 'First time (mm:ss)'))),
          const SizedBox(height: 8),
          TextField(controller: every, decoration: fieldDeco(L('Повтор каждые (мм:сс), пусто — один раз', 'Repeat every (mm:ss), empty — once'))),
          const SizedBox(height: 8),
          TextField(controller: lead, keyboardType: TextInputType.number, decoration: fieldDeco(L('Предупредить за, сек', 'Warn before, sec'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Сохранить', 'Save'))),
        ],
      ),
    );
    if (ok == true) {
      tools.updateTimer(e.copyWith(
        first: parse(first.text) ?? e.first,
        every: every.text.trim().isEmpty ? 0 : (parse(every.text) ?? e.every),
        lead: int.tryParse(lead.text.trim()) ?? e.lead,
      ));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      first.dispose();
      every.dispose();
      lead.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Тайминги', 'Timings'), style: T.h2),
        actions: [TextButton(onPressed: tools.resetTimers, child: Text(L('Сбросить', 'Reset')))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          for (final e in tools.timerEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                onTap: () => _edit(context, tools, e),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: T.body.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        L('с ${mmss(e.first)}${e.every > 0 ? ', каждые ${mmss(e.every)}' : ''}'
                        '${e.until > 0 ? ' до ${mmss(e.until)}' : ''}${e.lead > 0 ? ' · предупредить за ${e.lead} с' : ''}', 'from ${mmss(e.first)}${e.every > 0 ? ', every ${mmss(e.every)}' : ''}'
                        '${e.until > 0 ? ' until ${mmss(e.until)}' : ''}${e.lead > 0 ? ' · warn ${e.lead}s before' : ''}'),
                        style: T.small,
                      ),
                    ]),
                  ),
                  Switch(
                    value: e.enabled,
                    activeTrackColor: C.accent,
                    onChanged: (v) => tools.updateTimer(e.copyWith(enabled: v)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            L('Нажми на событие, чтобы изменить время. Значения по умолчанию — для последних известных патчей; '
            'если Valve поменяет тайминги, поправь их здесь.', 'Tap an event to change its time. Defaults are for the latest known patches; '
            'if Valve changes the timings, adjust them here.'),
            style: T.small,
          ),
        ],
      ),
    );
  }
}
