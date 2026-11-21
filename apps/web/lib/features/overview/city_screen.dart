import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';

final wardsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => List<Map<String, dynamic>>.from((await apiGet(ref, '/wards'))['items']));

/// Ward outlines from the bundled file: code to a ring of (lon, lat) points.
final wardShapesProvider = FutureProvider<Map<String, List<Offset>>>((ref) async {
  final geo = jsonDecode(await rootBundle.loadString('assets/geo/wards.geojson'));
  return {
    for (final f in geo['features'])
      f['properties']['ward_code'] as String: [
        for (final p in f['geometry']['coordinates'][0]) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
  };
});

/// Five steps of spend against budget. The label always accompanies the colour.
const shareSteps = ['< 80%', '80–90%', '90–100%', '100–110%', '> 110%'];
int shareStep(num share) => share < 0.8 ? 0 : share < 0.9 ? 1 : share <= 1.0 ? 2 : share <= 1.1 ? 3 : 4;

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityState();
}

class _CityState extends ConsumerState<CityScreen> {
  String? _selected;
  String _sort = 'spend_share';
  bool _asc = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(wardsProvider),
      onRetry: () => ref.invalidate(wardsProvider),
      lines: 8,
      builder: (wards) {
        num sum(String k) => wards.fold<num>(0, (s, w) => s + (w[k] as num));
        final over = wards.where((w) => (w['spend_share'] as num) > 1).length;
        final sorted = [...wards]..sort((a, b) {
            final x = a[_sort], y = b[_sort];
            final r = x is num ? x.compareTo(y as num) : '$x'.compareTo('$y');
            return _asc ? r : -r;
          });
        final wideEnough = MediaQuery.sizeOf(context).width >= 1000;
        final map = SectionCard(
          title: t('city.legend'),
          child: Column(children: [
            AspectRatio(
              aspectRatio: 0.72,
              child: AsyncView(
                value: ref.watch(wardShapesProvider),
                builder: (shapes) => WardMap(shapes: shapes, wards: wards, selected: _selected, onTap: (code) => setState(() => _selected = code), onOpen: (code) => context.goWard(code)),
              ),
            ),
            const SizedBox(height: Gap.md),
            const _Legend(),
          ]),
        );
        final table = SectionCard(
          title: t('city.overBudget', {'n': over}),
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.lg, Gap.sm, Gap.sm),
          child: _WardTable(sorted, selected: _selected, sort: _sort, asc: _asc, onSort: (k) => setState(() {
                _asc = _sort == k ? !_asc : false;
                _sort = k;
              }), onSelect: (code) => setState(() => _selected = code)),
        );
        return PageBody(children: [
          Text(t('city.title'), style: tt.titleLarge),
          _Tiles([
            StatTile(label: t('city.budget'), value: fmt.money(sum('budget'))),
            StatTile(label: t('city.spent'), value: fmt.money(sum('spend')), sub: fmt.pct(sum('spend') / sum('budget'))),
            StatTile(label: t('city.openFlags'), value: fmt.money(sum('open_flag_amount')), sub: t('ward.flagsN', {'n': fmt.count(sum('open_flags'))}), tone: Tone.flag),
            StatTile(label: t('city.reopened'), value: fmt.money(sum('reopened_spend')), sub: t('ward.jobs', {'n': fmt.count(sum('reopened_jobs'))})),
          ]),
          if (wideEnough)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 420, child: map), const SizedBox(width: Gap.lg), Expanded(child: table)])
          else ...[table, map],
        ]);
      },
    );
  }
}

/// Lays tiles out in a row when there is room and a 2-column grid when there is not.
class _Tiles extends StatelessWidget {
  const _Tiles(this.tiles);
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final cols = box.maxWidth >= 900 ? tiles.length : box.maxWidth >= 480 ? 2 : 1;
        final w = (box.maxWidth - Gap.lg * (cols - 1)) / cols;
        return Wrap(spacing: Gap.lg, runSpacing: Gap.lg, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
      });
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    return Wrap(spacing: Gap.md, runSpacing: Gap.xs, children: [
      for (var i = 0; i < 5; i++)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: c.mapScale[i], border: Border.all(color: c.borderStrong), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: Gap.xs),
          Text(shareSteps[i], style: Theme.of(context).textTheme.bodySmall),
        ]),
    ]);
  }
}

class _WardTable extends ConsumerWidget {
  const _WardTable(this.wards, {required this.selected, required this.sort, required this.asc, required this.onSort, required this.onSelect});
  final List<Map<String, dynamic>> wards;
  final String? selected;
  final String sort;
  final bool asc;
  final void Function(String key) onSort;
  final void Function(String code) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    Widget head(String key, String label, {int flex = 2, bool end = true}) => Expanded(
          flex: flex,
          child: InkWell(
            onTap: () => onSort(key),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: Gap.xs),
              child: Row(mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
                Flexible(child: Text(label, style: tt.labelMedium)),
                if (sort == key) Icon(asc ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: c.textSecondary),
              ]),
            ),
          ),
        );
    Widget cell(String text, {int flex = 2, TextStyle? style}) =>
        Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.xs), child: Text(text, textAlign: TextAlign.end, style: style ?? tt.bodyMedium)));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
        child: Row(children: [
          head('ward_code', t('col.ward'), flex: narrow ? 2 : 4, end: false),
          if (!narrow) head('budget', t('col.budget')),
          head('spend', t('col.spent')),
          head('spend_share', t('col.share')),
          head('open_flags', t('col.flags')),
          const SizedBox(width: 24),
        ]),
      ),
      const Divider(),
      for (final w in wards)
        Material(
          color: w['ward_code'] == selected ? c.primaryContainer : Colors.transparent,
          child: InkWell(
            onTap: () => context.goWard(w['ward_code']),
            onHover: (h) => h ? onSelect(w['ward_code']) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.sm),
              child: Row(children: [
                Expanded(
                  flex: narrow ? 2 : 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${w['ward_code']}', style: tt.titleMedium),
                      if (!narrow) Text('${w['ward_name']}', style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
                if (!narrow) cell(fmt.money(w['budget'])),
                cell(fmt.money(w['spend'])),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    // Over budget is the one place red appears here, and it carries its figure.
                    child: (w['spend_share'] as num) > 1 ? Pill(fmt.pct(w['spend_share']), tone: Tone.error, icon: Icons.arrow_upward) : Text(fmt.pct(w['spend_share']), style: tt.bodyMedium),
                  ),
                ),
                cell('${w['open_flags']}'),
                SizedBox(width: 24, child: Icon(Icons.chevron_right, size: 18, color: c.textSecondary)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Ward outlines shaded by spend against budget. No background tiles, so it needs no network.
class WardMap extends StatelessWidget {
  const WardMap({super.key, required this.shapes, required this.wards, required this.selected, required this.onTap, required this.onOpen});
  final Map<String, List<Offset>> shapes;
  final List<Map<String, dynamic>> wards;
  final String? selected;
  final void Function(String code) onTap, onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final size = box.biggest;
        final paths = _project(shapes, size);
        String? hit(Offset p) => paths.entries.where((e) => e.value.contains(p)).map((e) => e.key).firstOrNull;
        return GestureDetector(
          onTapUp: (d) {
            final code = hit(d.localPosition);
            if (code == null) return;
            code == selected ? onOpen(code) : onTap(code);
          },
          onDoubleTapDown: (d) {
            final code = hit(d.localPosition);
            if (code != null) onOpen(code);
          },
          child: CustomPaint(
            size: size,
            painter: _MapPainter(paths, {for (final w in wards) w['ward_code'] as String: w['spend_share'] as num}, selected, SathiColors.of(context), Theme.of(context).textTheme.labelMedium!),
          ),
        );
      });

  /// Fits all outlines into the box, correcting longitude for Mumbai's latitude.
  static Map<String, Path> _project(Map<String, List<Offset>> shapes, Size size) {
    final all = shapes.values.expand((r) => r);
    final minX = all.map((p) => p.dx).reduce(math.min), maxX = all.map((p) => p.dx).reduce(math.max);
    final minY = all.map((p) => p.dy).reduce(math.min), maxY = all.map((p) => p.dy).reduce(math.max);
    final k = math.cos((minY + maxY) / 2 * math.pi / 180);
    final scale = math.min(size.width / ((maxX - minX) * k), size.height / (maxY - minY));
    final ox = (size.width - (maxX - minX) * k * scale) / 2, oy = (size.height - (maxY - minY) * scale) / 2;
    return {
      for (final e in shapes.entries)
        e.key: (Path()..addPolygon([for (final p in e.value) Offset(ox + (p.dx - minX) * k * scale, oy + (maxY - p.dy) * scale)], true)),
    };
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.paths, this.share, this.selected, this.c, this.label);
  final Map<String, Path> paths;
  final Map<String, num> share;
  final String? selected;
  final SathiColors c;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in paths.entries) {
      final step = shareStep(share[e.key] ?? 0);
      canvas.drawPath(e.value, Paint()..color = c.mapScale[step]);
      canvas.drawPath(e.value, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.key == selected ? 3 : 1
        ..color = e.key == selected ? c.textPrimary : c.surface);
    }
    // Labels on top, so no outline covers them.
    for (final e in paths.entries) {
      final tp = TextPainter(text: TextSpan(text: e.key, style: label.copyWith(color: c.onMapScale[shareStep(share[e.key] ?? 0)], fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, e.value.getBounds().center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.selected != selected || old.share != share || old.c != c;
}
