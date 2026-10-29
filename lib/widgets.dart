import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(10);
    return Material(
      color: color ?? C.surface,
      borderRadius: r,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(borderRadius: r, border: Border.all(color: borderColor ?? C.border)),
          child: child,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: T.section)),
          if (trailing != null) trailing!,
        ]),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  const Pill(this.text, {super.key, this.color = C.accent, this.icon, this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 14, color: filled ? Colors.white : color), const SizedBox(width: 5)],
            Text(text, style: TextStyle(color: filled ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// Картинка героя (горизонтальная, 16:9) с запасным вариантом, если нет интернета.
class HeroImg extends StatelessWidget {
  final DHero hero;
  final double width;
  final double? height;
  final double radius;
  final bool dim;
  const HeroImg(this.hero, {super.key, required this.width, this.height, this.radius = 6, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final h = height ?? width * 0.5625;
    Widget fallback() => Container(
          width: width,
          height: h,
          alignment: Alignment.center,
          color: C.attr(hero.attr).withValues(alpha: 0.25),
          child: Text(
            hero.name.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join(),
            style: TextStyle(color: C.attr(hero.attr), fontWeight: FontWeight.w800, fontSize: width / 5),
          ),
        );
    Widget img = CachedNetworkImage(
      imageUrl: hero.image,
      width: width,
      height: h,
      fit: BoxFit.cover,
      placeholder: (_, __) => fallback(),
      errorWidget: (_, __, ___) => fallback(),
    );
    if (dim) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.45, 0,
        ]),
        child: img,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

String pct(double v, {int digits = 1}) => '${(v * 100).toStringAsFixed(digits).replaceAll('.', ',')}%';

String signedPct(double v, {int digits = 1}) => '${v >= 0 ? '+' : '−'}${pct(v.abs(), digits: digits)}';

String posShort(int p) => 'поз. $p';

String positionsText(DHero h) => h.positions.map((p) => positionNames[p] ?? '$p').join(' / ');

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: C.text)),
      backgroundColor: C.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: C.border)),
    ));
}

Future<T?> showSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: child,
      ),
    );

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(4)),
        ),
      );
}

/// Иконка предмета (88×64 в оригинале).
class ItemImg extends StatelessWidget {
  final String itemKey;
  final double width;
  const ItemImg(this.itemKey, {super.key, this.width = 40});

  @override
  Widget build(BuildContext context) {
    final h = width * 64 / 88;
    Widget fb() => Container(width: width, height: h, color: C.surface2);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/$itemKey.png',
        width: width,
        height: h,
        fit: BoxFit.cover,
        placeholder: (_, __) => fb(),
        errorWidget: (_, __, ___) => fb(),
      ),
    );
  }
}

/// Столбики шанса победы по отрезкам времени: выше 50% — зелёный, ниже — красный.
class ChanceBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const ChanceBars({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(pct(values[i], digits: 0),
                    style: T.num(13, color: values[i] >= 0.5 ? C.ally : C.enemy)),
                const SizedBox(height: 4),
                Container(
                  height: 8 + 80 * ((values[i] - 0.3) / 0.4).clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: (values[i] >= 0.5 ? C.ally : C.enemy).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(i < labels.length ? labels[i] : '', style: const TextStyle(fontSize: 10.5, color: C.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}
