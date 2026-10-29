import 'data.dart';
import 'engine.dart';
import 'knowledge.dart';

/// Одна строка чек-листа состава.
class CheckItem {
  final String title;
  final String detail;
  final int level; // 2 — отлично, 1 — нормально, 0 — проблема
  const CheckItem(this.title, this.detail, this.level);
}

class Composition {
  final List<CheckItem> checks;
  final double magicShare; // доля магического урона 0..1
  const Composition(this.checks, this.magicShare);
}

int _count(List<DHero> t, bool Function(DHero) f) => t.where(f).length;

String _names(List<DHero> t, bool Function(DHero) f) => t.where(f).map((h) => h.name).join(', ');

Composition analyzeTeam(List<DHero> t) {
  if (t.isEmpty) return const Composition([], 0);
  final checks = <CheckItem>[];
  bool initiator(DHero h) => h.has('Initiator');
  bool disabler(DHero h) => h.has('Disabler');
  bool saver(DHero h) => savers.contains(h.key);
  bool pusher(DHero h) => h.has('Pusher');
  bool durable(DHero h) => h.has('Durable');
  bool carry(DHero h) => h.has('Carry');
  bool healer(DHero h) => healers.contains(h.key);
  bool magic(DHero h) => magicDamage.contains(h.key);

  final full = t.length >= 5;
  void add(String title, int n, int good, String names, String missing) {
    final level = n >= good ? 2 : (n > 0 ? 1 : (full ? 0 : 1));
    checks.add(CheckItem(title, n == 0 ? missing : names, level));
  }

  add('Инициация', _count(t, initiator), 1, _names(t, initiator), 'Нет героя, который начинает драку');
  add('Контроль', _count(t, disabler), 2, _names(t, disabler), 'Мало станов и замедлений');
  add('Сейвы', _count(t, saver), 1, _names(t, saver), 'Некому спасать союзников');
  add('Фронтлайн', _count(t, durable), 1, _names(t, durable), 'Нет крепкого героя впереди');
  add('Пуш', _count(t, pusher), 1, _names(t, pusher), 'Тяжело ломать вышки');
  add('Лечение', _count(t, healer), 1, _names(t, healer), 'Нет лечения — важны регенерация и бутылки');
  add('Кор на поздний этап', _count(t, carry), 1, _names(t, carry), 'Нет керри — заканчивайте игру раньше');

  final m = _count(t, magic);
  final share = m / t.length;
  if (t.length >= 3) {
    if (share >= 0.8) {
      checks.add(const CheckItem('Тип урона', 'Почти весь урон магический — враги соберут BKB и Pipe', 0));
    } else if (share <= 0.2) {
      checks.add(const CheckItem('Тип урона', 'Почти весь урон физический — враги соберут броню и Ghost', 0));
    } else {
      checks.add(CheckItem('Тип урона', 'Магический и физический урон сбалансированы (${(share * 100).round()}% магии)', 2));
    }
  }
  return Composition(checks, share);
}

/// Предметы против состава противника.
List<ItemTip> itemTips(List<DHero> enemies) {
  final tips = <ItemTip>[];
  if (enemies.isEmpty) return tips;
  List<String> who(Set<String> s) => enemies.where((h) => s.contains(h.key)).map((h) => h.name).toList();
  final magicN = enemies.where((h) => magicDamage.contains(h.key)).length;
  final physN = enemies.where((h) => !magicDamage.contains(h.key) && (h.has('Carry') || h.positions.contains(1))).length;
  final disablers = enemies.where((h) => h.has('Disabler')).length;

  if (magicN >= 3) {
    tips.add(ItemTip('Много магии', 'Магический урон: ${enemies.where((h) => magicDamage.contains(h.key)).map((h) => h.name).join(', ')}',
        const ['black_king_bar', 'pipe', 'glimmer_cape', 'eternal_shroud']));
  }
  if (physN >= 2) {
    tips.add(const ItemTip('Сильный физический урон', 'Несколько керри с уроном с руки',
        ['ghost', 'shivas_guard', 'crimson_guard', 'heavens_halberd', 'solar_crest']));
  }
  final heal = who(healers);
  if (heal.isNotEmpty) {
    tips.add(ItemTip('Лечение у врагов', heal.join(', '), const ['spirit_vessel', 'shivas_guard', 'skadi']));
  }
  final inv = who(invisible);
  if (inv.isNotEmpty) {
    tips.add(ItemTip('Невидимость', inv.join(', '), const ['dust', 'ward_sentry', 'gem']));
  }
  final ill = who(illusions);
  if (ill.isNotEmpty) {
    tips.add(ItemTip('Иллюзии и призывы', ill.join(', '), const ['bfury', 'mjollnir', 'radiance', 'shivas_guard']));
  }
  final ev = who(evasion);
  if (ev.isNotEmpty) {
    tips.add(ItemTip('Уклонение', ev.join(', '), const ['monkey_king_bar', 'bloodthorn']));
  }
  final br = who(breakTargets);
  if (br.isNotEmpty) {
    tips.add(ItemTip('Сильные пассивки', br.join(', '), const ['silver_edge']));
  }
  final st = who(singleTarget);
  if (st.isNotEmpty) {
    tips.add(ItemTip('Опасные заклинания в цель', st.join(', '), const ['sphere', 'lotus_orb']));
  }
  final sil = who(silencers);
  if (sil.isNotEmpty) {
    tips.add(ItemTip('Сайленсы', sil.join(', '), const ['manta', 'cyclone', 'lotus_orb']));
  }
  if (disablers >= 3) {
    tips.add(const ItemTip('Много контроля', 'Три и больше героев со станами', ['black_king_bar', 'force_staff', 'glimmer_cape']));
  }
  final sv = who(savers);
  if (sv.length >= 2) {
    tips.add(ItemTip('Сейвы у врагов', sv.join(', '), const ['nullifier']));
  }
  return tips;
}

/// Шанс победы по длительности матча (4 отрезка). Пусто, если нет данных.
List<double> timeCurve(Engine e, List<DHero> allies, List<DHero> enemies) {
  if (allies.isEmpty && enemies.isEmpty) return const [];
  if (!e.d.hasDurations) return const [];
  final pairs = e.teamLogit(allies, enemies) - _baseSum(e, allies) + _baseSum(e, enemies);
  return [
    for (var b = 0; b < 4; b++)
      sigmoid(pairs + _durSum(allies, b) - _durSum(enemies, b)).clamp(0.05, 0.95).toDouble(),
  ];
}

double _baseSum(Engine e, List<DHero> t) => t.fold(0.0, (s, h) => s + e.base(h));

double _durSum(List<DHero> t, int b) => t.fold(0.0, (s, h) => s + logit(b < h.dur.length ? h.dur[b] : 0.5));

/// Линия: наши герои против их героев.
class Lane {
  final String name;
  final List<DHero> ours;
  final List<DHero> theirs;
  final double score; // доля вероятности: >0 — линия в нашу пользу
  const Lane(this.name, this.ours, this.theirs, this.score);
}

class LanePlan {
  final List<Lane> lanes;
  final String? tip;
  const LanePlan(this.lanes, this.tip);
}

double _laneScore(StatsData d, List<DHero> ours, List<DHero> theirs) {
  var s = 0.0;
  for (final a in ours) {
    for (final b in theirs) {
      s += d.advantage(a, b);
    }
  }
  if (ours.length == 2) s += d.synergy(ours[0], ours[1]);
  if (theirs.length == 2) s -= d.synergy(theirs[0], theirs[1]);
  return s;
}

List<DHero> _byPos(List<DHero> t, Map<int, int> pos, List<int> ps) =>
    [for (final p in ps) ...t.where((h) => pos[h.id] == p)];

LanePlan lanes(StatsData d, List<DHero> allies, List<DHero> enemies) {
  if (allies.length < 3 || enemies.length < 3) return const LanePlan([], null);
  final ap = Engine.assign(allies).$2, ep = Engine.assign(enemies).$2;
  List<Lane> build(Map<int, int> ours) => [
        Lane('Лёгкая линия', _byPos(allies, ours, [1, 5]), _byPos(enemies, ep, [3, 4]),
            _laneScore(d, _byPos(allies, ours, [1, 5]), _byPos(enemies, ep, [3, 4]))),
        Lane('Мид', _byPos(allies, ours, [2]), _byPos(enemies, ep, [2]),
            _laneScore(d, _byPos(allies, ours, [2]), _byPos(enemies, ep, [2]))),
        Lane('Сложная линия', _byPos(allies, ours, [3, 4]), _byPos(enemies, ep, [1, 5]),
            _laneScore(d, _byPos(allies, ours, [3, 4]), _byPos(enemies, ep, [1, 5]))),
      ];
  final now = build(ap);
  // Проверяем, не лучше ли поменять саппортов (4 ↔ 5) местами.
  String? tip;
  final s4 = allies.where((h) => ap[h.id] == 4).toList(), s5 = allies.where((h) => ap[h.id] == 5).toList();
  if (s4.length == 1 && s5.length == 1) {
    final swapped = {...ap, s4.first.id: 5, s5.first.id: 4};
    final alt = build(swapped);
    double total(List<Lane> l) => l.fold(0.0, (s, x) => s + x.score);
    if (total(alt) - total(now) > 0.01) {
      tip = 'Попробуй поменять саппортов: ${s4.first.name} на лёгкую линию, ${s5.first.name} на сложную '
          '(${(100 * (total(alt) - total(now))).toStringAsFixed(1)}% в сумме по линиям).';
    }
  }
  return LanePlan(now, tip);
}
