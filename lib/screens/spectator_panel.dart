import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../gsi.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'timer_screen.dart' show mmss;

/// Режим зрителя (реплей, Dota TV, наблюдатель в лобби): все 10 игроков —
/// перезарядки способностей, предметы, LH/DN, GPM/XPM, золото, серия убийств.
class SpectatorPanel extends StatelessWidget {
  final bool compact;
  const SpectatorPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gsi,
      builder: (context, _) {
        final g = gsi.last;
        if (g == null || !gsi.live || !g.spectating) return _hint();
        final radiant = g.players.where((p) => p.radiant).toList();
        final dire = g.players.where((p) => !p.radiant).toList();
        int nw(List<GsiPlayer> l) => l.fold(0, (s, p) => s + p.netWorth);
        final lead = nw(radiant) - nw(dire);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              Text(mmss(g.clock ?? 0), style: T.num(compact ? 16 : 20)),
              const Spacer(),
              Text(L('Преимущество: ', 'Lead: '), style: T.small),
              Text(
                lead == 0 ? '0' : '${lead > 0 ? L('Свет', 'Radiant') : L('Тьма', 'Dire')} +${_k(lead.abs())}',
                style: T.num(compact ? 12 : 14, color: lead >= 0 ? C.ally : C.enemy),
              ),
            ]),
          ),
          _team(context, L('Свет', 'Radiant'), radiant, C.ally),
          _team(context, L('Тьма', 'Dire'), dire, C.enemy),
        ]);
      },
    );
  }

  static String _k(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v';

  Widget _hint() => AppCard(
        padding: const EdgeInsets.all(10),
        child: Text(
          L('Данные всех 10 игроков Dota присылает только в режиме зрителя: реплей, Dota TV или наблюдатель в лобби. '
              'В своём матче видны только твои данные (вкладка «Матч»).',
              'Dota sends data for all 10 players only when spectating: a replay, Dota TV or a lobby observer. '
              'In your own match only your data is available (Match tab).'),
          style: T.small,
        ),
      );

  Widget _team(BuildContext context, String title, List<GsiPlayer> players, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(title, style: T.section.copyWith(fontSize: compact ? 12 : 13)),
          const Spacer(),
          Text('${players.fold(0, (s, p) => s + p.kills)} ${L('уб.', 'kills')} · ${_k(players.fold(0, (s, p) => s + p.netWorth))}',
              style: T.small.copyWith(fontSize: 11)),
        ]),
      ),
      for (final p in players) _PlayerRow(p, compact: compact, color: color),
    ]);
  }
}

class _PlayerRow extends StatelessWidget {
  final GsiPlayer p;
  final bool compact;
  final Color color;
  const _PlayerRow(this.p, {required this.compact, required this.color});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final hero = s.data?.byId[p.heroId] ?? s.data?.heroes.where((h) => h.key == p.heroName).firstOrNull;
    final c = compact;
    final icon = c ? 26.0 : 30.0;
    final small = T.small.copyWith(fontSize: c ? 10.5 : 11.5);
    final numStyle = T.num(c ? 11 : 12.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.all(6),
        borderColor: p.alive ? null : C.enemy.withValues(alpha: 0.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Stack(children: [
              hero != null
                  ? HeroImg(hero, width: c ? 46 : 56, dim: !p.alive)
                  : Container(width: c ? 46 : 56, height: (c ? 46 : 56) * 0.5625, color: C.surface2),
              Positioned(
                right: 1,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  color: Colors.black54,
                  child: Text('${p.level}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              if (!p.alive)
                Positioned.fill(
                  child: Center(child: Text('${p.respawn}', style: T.num(14, color: Colors.white))),
                ),
            ]),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      p.name.isNotEmpty ? p.name : (hero?.name ?? p.heroName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(fontSize: c ? 11.5 : 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (p.killStreak >= 3) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('🔥${p.killStreak}', style: T.num(10, color: C.gold)),
                    ),
                  ],
                ]),
                // Полоски здоровья и маны.
                const SizedBox(height: 2),
                _bar(p.healthPct, C.ally),
                const SizedBox(height: 1),
                _bar(p.manaPct, C.intel),
              ]),
            ),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${p.kills}/${p.deaths}/${p.assists}', style: numStyle),
              Text('${p.gold} 🪙', style: T.num(c ? 10.5 : 11.5, color: C.gold)),
            ]),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 2, children: [
            Text('LH/DN ${p.lastHits}/${p.denies}', style: small),
            Text('GPM ${p.gpm}', style: small),
            Text('XPM ${p.xpm}', style: small),
            Text('NW ${SpectatorPanel._k(p.netWorth)}', style: small),
            if (p.buybackCd > 0) Text(L('выкуп ${mmss(p.buybackCd)}', 'BB ${mmss(p.buybackCd)}'), style: small.copyWith(color: C.enemy)),
          ]),
          const SizedBox(height: 4),
          // Способности с перезарядкой.
          Wrap(spacing: 3, runSpacing: 3, children: [
            for (final a in p.skills) _Cd(image: a.image, cooldown: a.cooldown, size: icon, dim: a.level == 0, ult: a.ultimate),
          ]),
          const SizedBox(height: 3),
          // Предметы: инвентарь, нейтральный, телепорт; рюкзак — бледнее.
          Wrap(spacing: 3, runSpacing: 3, children: [
            for (final it in p.items.where((i) => !i.backpack)) _ItemCd(it, width: icon * 1.3),
            if (p.neutral != null) _ItemCd(p.neutral!, width: icon * 1.3, round: true),
            if (p.tp != null) _ItemCd(p.tp!, width: icon * 1.3),
            for (final it in p.items.where((i) => i.backpack)) Opacity(opacity: 0.45, child: _ItemCd(it, width: icon * 1.1)),
          ]),
        ]),
      ),
    );
  }

  Widget _bar(int pct, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          minHeight: 3,
          backgroundColor: C.surface2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

/// Квадратик способности с числом секунд перезарядки.
class _Cd extends StatelessWidget {
  final String image;
  final int cooldown;
  final double size;
  final bool dim;
  final bool ult;
  const _Cd({required this.image, required this.cooldown, required this.size, this.dim = false, this.ult = false});

  @override
  Widget build(BuildContext context) {
    final fb = Container(width: size, height: size, color: C.surface2);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ult ? C.gold.withValues(alpha: 0.7) : Colors.transparent, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(children: [
          Opacity(
            opacity: dim ? 0.3 : 1,
            child: CachedNetworkImage(
              imageUrl: image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => fb,
              errorWidget: (_, __, ___) => fb,
            ),
          ),
          if (cooldown > 0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                alignment: Alignment.center,
                child: Text('$cooldown', style: T.num(size * 0.42, color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Предмет с перезарядкой и зарядами.
class _ItemCd extends StatelessWidget {
  final GsiItem it;
  final double width;
  final bool round;
  const _ItemCd(this.it, {required this.width, this.round = false});

  @override
  Widget build(BuildContext context) {
    final h = width * 64 / 88;
    return ClipRRect(
      borderRadius: BorderRadius.circular(round ? h / 2 : 4),
      child: Stack(children: [
        ItemImg(it.key, width: width),
        if (it.cooldown > 0)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: Text('${it.cooldown}', style: T.num(h * 0.5, color: Colors.white)),
            ),
          ),
        if (it.charges > 0 && it.cooldown <= 0)
          Positioned(
            right: 1,
            bottom: 0,
            child: Text('${it.charges}',
                style: TextStyle(fontSize: h * 0.38, color: Colors.white, fontWeight: FontWeight.w800, shadows: const [Shadow(blurRadius: 2)])),
          ),
      ]),
    );
  }
}
