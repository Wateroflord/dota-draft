import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';

/// Мини-игра «Добивания»: бей крипа в момент, когда твой удар его добьёт. Учитывается замах (задержка удара).
class LastHitScreen extends StatefulWidget {
  const LastHitScreen({super.key});

  @override
  State<LastHitScreen> createState() => _LastHitScreenState();
}

class _LastHitScreenState extends State<LastHitScreen> {
  static const rounds = 20;
  final rnd = math.Random();
  Timer? _t;
  bool hard = false;
  bool running = false;
  int creep = 0;
  double maxHp = 550, hp = 550;
  double nextAlly = 0; // через сколько секунд следующий удар союзных крипов
  double? swing; // до попадания моего удара
  bool deny = false; // свой крип — надо добить, когда меньше половины
  int hits = 0, misses = 0, early = 0;
  String last = '';
  Color lastColor = C.muted;
  double pause = 0;
  final focus = FocusNode();

  int get dmgMin => 52;
  int get dmgMax => 58;
  double get attackPoint => 0.35;

  @override
  void dispose() {
    _t?.cancel();
    focus.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      running = true;
      creep = 0;
      hits = misses = early = 0;
      last = '';
      _spawn();
    });
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick(0.04));
    focus.requestFocus();
  }

  void _spawn() {
    creep++;
    maxHp = 550;
    hp = maxHp;
    swing = null;
    deny = rnd.nextDouble() < 0.25;
    nextAlly = 0.4 + rnd.nextDouble() * 0.4;
    pause = 0;
  }

  void _result(String text, Color c, {bool hit = false, bool miss = false}) {
    last = text;
    lastColor = c;
    if (hit) hits++;
    if (miss) misses++;
    pause = 0.9;
  }

  void _tick(double dt) {
    if (!running) return;
    setState(() {
      if (pause > 0) {
        pause -= dt;
        if (pause <= 0) {
          if (creep >= rounds) {
            running = false;
            _t?.cancel();
            final tools = ToolsScope.read(context);
            if (hits > tools.lastHitBest) tools.setLastHitBest(hits);
          } else {
            _spawn();
          }
        }
        return;
      }
      // Удары крипов: 3–4 крипа, каждый ~20 урона.
      nextAlly -= dt;
      if (nextAlly <= 0) {
        hp -= (hard ? 18 : 16) + rnd.nextInt(hard ? 12 : 8);
        nextAlly = (hard ? 0.18 : 0.28) + rnd.nextDouble() * (hard ? 0.3 : 0.4);
        if (hp <= 0) {
          hp = 0;
          swing = null;
          _result(deny ? L('Крипа добили враги', 'Denied by the enemy') : L('Упустил — крипа добили другие', 'Missed — someone else got it'), C.enemy,
              miss: true);
          return;
        }
      }
      if (swing != null) {
        swing = swing! - dt;
        if (swing! <= 0) {
          swing = null;
          final dmg = dmgMin + rnd.nextInt(dmgMax - dmgMin + 1);
          if (deny && hp > maxHp / 2) {
            _result(L('Своего крипа можно добить, только когда у него меньше половины здоровья', 'You can deny only below half HP'), C.gold);
            early++;
            pause = 0;
          } else if (hp <= dmg) {
            hp = 0;
            _result(deny ? L('Денай!', 'Denied!') : L('Добил! +40 золота', 'Last hit! +40 gold'), C.ally, hit: true);
          } else {
            hp -= dmg;
            early++;
            last = L('Рано — крип выжил (${hp.round()} здоровья)', 'Too early — the creep survived (${hp.round()} HP)');
            lastColor = C.gold;
          }
        }
      }
    });
  }

  void _attack() {
    if (!running || pause > 0 || swing != null) return;
    setState(() => swing = attackPoint);
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    final frac = (hp / maxHp).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Тренировка добиваний', 'Last-hit trainer'), style: T.h2),
      ),
      body: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.space || e.logicalKey == LogicalKeyboardKey.keyA)) {
            _attack();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
          children: [
            Text(
              L('Нажимай «Удар» (или пробел), когда твой удар добьёт крипа. Удар попадает через ${(attackPoint * 1000).round()} мс, урон $dmgMin–$dmgMax. '
                  'Свои крипы (зелёные) можно добить, только когда у них меньше половины здоровья.',
                  'Tap Attack (or Space) so your hit kills the creep. The hit lands after ${(attackPoint * 1000).round()} ms, damage $dmgMin–$dmgMax. '
                  'Your own creeps (green) can be denied only below half HP.'),
              style: T.small,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Pill(L('Обычный', 'Normal'), color: C.accent, filled: !hard, onTap: running ? null : () => setState(() => hard = false)),
              const SizedBox(width: 6),
              Pill(L('Сложный', 'Hard'), color: C.accent, filled: hard, onTap: running ? null : () => setState(() => hard = true)),
              const Spacer(),
              Text(L('Рекорд: ${tools.lastHitBest}/$rounds', 'Best: ${tools.lastHitBest}/$rounds'), style: T.small.copyWith(color: C.gold)),
            ]),
            const SizedBox(height: 16),
            AppCard(
              child: Column(children: [
                Text(running ? L('Крип $creep из $rounds', 'Creep $creep of $rounds') : L('Готов?', 'Ready?'), style: T.small),
                const SizedBox(height: 12),
                GestureDetector(
                  onTapDown: (_) => _attack(),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (deny ? C.ally : C.enemy).withValues(alpha: hp > 0 ? 0.25 : 0.06),
                      border: Border.all(color: deny ? C.ally : C.enemy, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Icon(swing != null ? Icons.flash_on : Icons.pest_control, size: 48, color: deny ? C.ally : C.enemy),
                  ),
                ),
                const SizedBox(height: 12),
                Stack(children: [
                  Container(height: 14, decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(height: 14, decoration: BoxDecoration(color: deny ? C.ally : C.enemy, borderRadius: BorderRadius.circular(4))),
                  ),
                  if (deny)
                    Positioned(left: 0, right: 0, top: 0, bottom: 0, child: Center(child: Container(width: 2, color: C.text))),
                ]),
                const SizedBox(height: 4),
                Text('${hp.round()} / ${maxHp.round()}', style: T.num(13)),
                const SizedBox(height: 10),
                SizedBox(height: 40, child: Text(last, textAlign: TextAlign.center, style: T.body.copyWith(color: lastColor))),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: running ? _attack : _start,
                    child: Text(running ? L('Удар', 'Attack') : (creep > 0 ? L('Ещё раз', 'Again') : L('Начать', 'Start')),
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(L('Добито: $hits', 'Hits: $hits'), style: T.num(14, color: C.ally))),
              Expanded(child: Text(L('Упущено: $misses', 'Missed: $misses'), style: T.num(14, color: C.enemy))),
              Expanded(child: Text(L('Рано: $early', 'Early: $early'), style: T.num(14, color: C.gold))),
            ]),
            if (!running && creep >= rounds) ...[
              const SizedBox(height: 10),
              Text(
                hits >= 16
                    ? L('Отлично! Это уровень хорошего керри.', 'Great! That is a solid carry level.')
                    : hits >= 11
                        ? L('Неплохо. Следи за полоской здоровья и жми чуть раньше — удар летит с задержкой.',
                            'Not bad. Watch the HP bar and press slightly earlier — the hit lands with a delay.')
                        : L('Тренируйся: жми, когда здоровья меньше примерно 70–80 — удар ещё долетит.',
                            'Keep practicing: press at about 70–80 HP — your hit still needs time to land.'),
                style: T.body,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
