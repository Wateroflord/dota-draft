import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme.dart';
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
    tts.setLanguage('ru-RU');
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
        title: const Text('Сколько сейчас в игре?', style: T.h2),
        content: Row(children: [
          Expanded(child: TextField(controller: m, keyboardType: TextInputType.number, decoration: fieldDeco('мин'))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: T.h2)),
          Expanded(child: TextField(controller: s, keyboardType: TextInputType.number, decoration: fieldDeco('сек'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Старт')),
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
      showToast(context, 'Сначала запусти таймер');
      return;
    }
    setState(() => oneShots.addAll(list));
    HapticFeedback.mediumImpact();
  }

  void _tick() {
    if (!mounted || !running) return;
    final t = now;
    final events = ToolsScope.read(context).timerEvents.where((e) => e.enabled);
    for (final e in events) {
      final next = e.nextAt(t);
      if (next == null) continue;
      if (e.lead > 0 && t == next - e.lead && fired.add('${e.id}@$next-lead')) {
        _say('Через ${e.lead} секунд — ${e.title.toLowerCase()}');
      }
      if (t == next && fired.add('${e.id}@$next')) {
        HapticFeedback.heavyImpact();
        _say(e.title);
      }
    }
    for (final o in oneShots) {
      if (o.lead > 0 && t == o.at - o.lead && fired.add('${o.title}@${o.at}-lead')) {
        _say('Через ${o.lead} секунд — ${o.title.toLowerCase()}');
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
        title: const Text('Таймеры матча', style: T.h2),
        actions: [
          IconButton(
            tooltip: 'Голос',
            icon: Icon(tools.voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
            onPressed: () => tools.setVoice(!tools.voice),
          ),
          IconButton(
            tooltip: 'Настроить тайминги',
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
              Text(running ? 'идёт игра' : (startedAt == null ? 'нажми «Старт» вместе с горном 0:00' : 'пауза'),
                  style: T.small),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size(0, 46)),
                    onPressed: startedAt == null ? () => _start() : _pause,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(startedAt == null ? 'Старт 0:00' : (running ? 'Пауза' : 'Продолжить')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: const BorderSide(color: C.border)),
                  onPressed: _setTime,
                  child: const Text('Задать время'),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _reset, icon: const Icon(Icons.restart_alt, color: C.muted)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _bigBtn('Рошан убит', Icons.whatshot, C.gold, () {
                _addOneShots([
                  _OneShot('Аегис пропадает', t + 300, 30),
                  _OneShot('Рошан может возродиться', t + 480, 20),
                  _OneShot('Рошан точно возродился', t + 660, 0),
                ]);
                showToast(context, 'Аегис до ${mmss(t + 300)}, Рошан с ${mmss(t + 480)} до ${mmss(t + 660)}');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _bigBtn('Торментор убит', Icons.diamond_outlined, C.intel, () {
                _addOneShots([_OneShot('Торментор возродился', t + 600, 20)]);
                showToast(context, 'Торментор вернётся в ${mmss(t + 600)}');
              }),
            ),
          ]),
          const SectionLabel('Ближайшие события'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              if (upcoming.isEmpty)
                const Padding(padding: EdgeInsets.all(14), child: Text('Нет включённых таймеров.', style: T.small)),
              for (final u in upcoming.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(u.$1, style: T.body)),
                    Text(mmss(u.$2), style: T.num(14, color: C.muted)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 56,
                      child: Text('через ${mmss(u.$2 - t)}',
                          textAlign: TextAlign.right,
                          style: T.small.copyWith(color: u.$2 - t <= 20 ? C.gold : C.muted)),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          const Text(
            'Экран не гаснет, пока таймер запущен. Если матч уже идёт — нажми «Задать время» и введи время с игровых часов. '
            'Тайминги можно поменять в настройках (иконка вверху), если в новом патче они изменятся.',
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
          TextField(controller: first, decoration: fieldDeco('Первый раз (мм:сс)')),
          const SizedBox(height: 8),
          TextField(controller: every, decoration: fieldDeco('Повтор каждые (мм:сс), пусто — один раз')),
          const SizedBox(height: 8),
          TextField(controller: lead, keyboardType: TextInputType.number, decoration: fieldDeco('Предупредить за, сек')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
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
        title: const Text('Тайминги', style: T.h2),
        actions: [TextButton(onPressed: tools.resetTimers, child: const Text('Сбросить'))],
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
                        'с ${mmss(e.first)}${e.every > 0 ? ', каждые ${mmss(e.every)}' : ''}'
                        '${e.until > 0 ? ' до ${mmss(e.until)}' : ''}${e.lead > 0 ? ' · предупредить за ${e.lead} с' : ''}',
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
          const Text(
            'Нажми на событие, чтобы изменить время. Значения по умолчанию — для последних известных патчей; '
            'если Valve поменяет тайминги, поправь их здесь.',
            style: T.small,
          ),
        ],
      ),
    );
  }
}
