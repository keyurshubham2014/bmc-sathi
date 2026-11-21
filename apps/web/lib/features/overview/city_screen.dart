import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

final wardsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => List<Map<String, dynamic>>.from((await apiGet(ref, '/wards'))['items']));

/// Ward outlines from the bundled file (OpenCity, CC0): code to its rings of points, largest first.
final wardShapesProvider = FutureProvider<Map<String, List<List<LatLng>>>>((ref) async {
  final geo = jsonDecode(await rootBundle.loadString('assets/geo/wards.geojson'));
  return {
    for (final f in geo['features'])
      f['properties']['ward_code'] as String: [
        for (final poly in f['geometry']['coordinates'])
          [for (final p in poly[0]) LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())],
      ]..sort((x, y) => y.length - x.length),
  };
});

/// Five steps of spend against budget: under 80 / 80–89 / 90–99 (up to 100 is within budget) / 100–110 / over 110.
const mapScale = [Tok.map1, Tok.map2, Tok.map3, Tok.map4, Tok.map5];
int shareStep(num share) => share < 0.8 ? 0 : share < 0.9 ? 1 : share <= 1.0 ? 2 : share <= 1.1 ? 3 : 4;
const _rows = 11;

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityState();
}

class _CityState extends ConsumerState<CityScreen> {
  String? _selected;
  String _query = '';
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final wardsAsync = ref.watch(wardsProvider);
    final flags = wardsAsync.value?.fold<num>(0, (s, w) => s + (w['open_flags'] as num)) ?? 0;
    return SetTopBar(
      title: t('city.top'),
      titleSuffix: t('city.topSuffix', {'n': wardsAsync.value?.length ?? 24}),
      action: AppButton.primary(t('city.review', {'n': fmt.count(flags)}), icon: Ico.flag, onPressed: () => context.go('/flags')),
      child: AsyncView(
        value: wardsAsync,
        onRetry: () => ref.invalidate(wardsProvider),
        lines: 8,
        builder: (raw) {
          final wards = [...raw]..sort((a, b) => (b['spend_share'] as num).compareTo(a['spend_share'] as num));
          if (wards.isEmpty) return EmptyState(t('city.noMatch'));
          final selected = _selected ?? wards.first['ward_code'] as String;
          final map = _MapPanel(wards: wards, selected: selected, onSelect: (c) => setState(() => _selected = c));
          final table = _wardsPanel(t, wards, selected);
          return LayoutBuilder(
            builder: (_, box) => PageBody(children: [
              _overview(t, wards),
              if (box.maxWidth >= 1000)
                // No IntrinsicHeight: the map and table hold LayoutBuilders, which cannot report intrinsic sizes.
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 43, child: map),
                  const SizedBox(width: Tok.gapPanels),
                  Expanded(flex: 54, child: table),
                ])
              else ...[table, map],
            ]),
          );
        },
      ),
    );
  }

  Widget _overview(Strings t, List<Map<String, dynamic>> wards) {
    num sum(String k) => wards.fold<num>(0, (s, w) => s + (w[k] as num));
    final budget = sum('budget'), spend = sum('spend');
    final over = [for (final w in wards) if ((w['spend_share'] as num) > 1) w['ward_code'] as String];
    final small = Tok.sub.copyWith(fontSize: 12.5);
    Widget box(IconData icon, Color fg, Color bg, Color line, String title, String sub, {bool round = false}) => Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, border: Border.all(color: line), borderRadius: BorderRadius.circular(round ? 18 : 10)),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: Tok.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: Tok.emph.copyWith(color: fg == Tok.red ? Tok.red : Tok.ink)),
              Text(sub, style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]);
    return Panel(
      title: t('city.overview'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatRow(children: [
          StatBlock(icon: Ico.budget, label: t('city.budget'), value: fmt.money(budget), sub: t('city.wardsN', {'n': wards.length})),
          StatBlock(
              icon: Ico.receipt,
              label: t('city.spent'),
              value: fmt.money(spend),
              sub: t('city.spentSub', {'pct': fmt.pct(spend / budget), 'n': fmt.count(sum('jobs'))})),
          StatBlock(
              icon: Ico.flag,
              tone: StatTone.amber,
              label: t('city.openFlags'),
              value: fmt.money(sum('open_flag_amount')),
              subLead: t('city.flagsN', {'n': fmt.count(sum('open_flags'))}),
              sub: t('city.unreviewed')),
          StatBlock(icon: Ico.reopened, label: t('city.reopenedSpend'), value: fmt.money(sum('reopened_spend')), sub: t('city.reopenedSub')),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: Tok.s4), child: Divider(height: 1, color: Tok.lineSoft)),
        StatRow(flex: const [1, 1, 2], children: [
          // Red only when some ward is actually over budget; the word and icon carry it too.
          over.isEmpty
              ? box(Ico.check, Tok.text2, Tok.inset, Tok.line, t('city.overBudget', {'n': 0}), '', round: true)
              : box(Ico.alert, Tok.red, Tok.redTint, Tok.redLine, t('city.overBudget', {'n': over.length}), over.join(', ')),
          box(Ico.check, Tok.text2, Tok.inset, Tok.line, t('city.withinN', {'n': wards.length - over.length}), t('city.withinSub'), round: true),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(t('city.barTitle'), style: small),
              const Spacer(),
              Text.rich(TextSpan(style: small.copyWith(color: Tok.ink, fontWeight: FontWeight.w500), children: [
                TextSpan(text: t('city.barLine', {'spent': fmt.money(spend), 'budget': fmt.money(budget)})),
                TextSpan(text: fmt.pct(spend / budget), style: TextStyle(color: spend > budget ? Tok.red : Tok.teal, fontWeight: FontWeight.w600)),
              ])),
            ]),
            const SizedBox(height: 8),
            BudgetBar(budget: budget, spent: spend, showLabels: false),
            const SizedBox(height: 6),
            Row(children: [
              Text(fmt.money(0), style: Tok.sub.copyWith(fontSize: 11.5)),
              const Spacer(),
              Text(t('budget.atBudget'), style: Tok.sub.copyWith(fontSize: 11.5)),
            ]),
          ]),
        ]),
      ]),
    );
  }

  Widget _wardsPanel(Strings t, List<Map<String, dynamic>> wards, String selected) {
    final q = _query.trim().toLowerCase();
    final found = q.isEmpty
        ? wards
        : wards.where((w) => '${w['ward_code']} ${w['ward_name']}'.toLowerCase().contains(q)).toList();
    final shown = _all ? found : found.take(_rows).toList();
    return Panel(
      title: t('city.wards'),
      sub: t('city.wardsSub', {'n': wards.length}),
      trailing: SizedBox(
        width: 210,
        height: Tok.controlH,
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: Tok.body,
          decoration: InputDecoration(
            isDense: true,
            hintText: t('city.search'),
            hintStyle: Tok.body.copyWith(color: Tok.text3),
            prefixIcon: const Icon(Ico.search, size: 16, color: Tok.text3),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            filled: true,
            fillColor: Tok.panel,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.teal, width: 2)),
          ),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (shown.isEmpty)
          EmptyState(t('city.noMatch'))
        else
          WorksTable(
            columns: [
              WorksColumn(t('col.ward'), flex: 1),
              WorksColumn(t('col.budget'), width: 86, numeric: true),
              WorksColumn(t('col.spent'), width: 86, numeric: true),
              WorksColumn(t('city.colShare'), width: 168, sorted: true),
              WorksColumn(t('city.colFlags'), width: 78, numeric: true),
            ],
            selected: shown.indexWhere((w) => w['ward_code'] == selected),
            onRowTap: (i) => context.goWard(shown[i]['ward_code']),
            rows: [for (final w in shown) _row(t, w, w['ward_code'] == selected)],
          ),
        const SizedBox(height: Tok.s3),
        Row(children: [
          Text(t('city.showing', {'n': shown.length, 'total': found.length}), style: Tok.sub),
          const SizedBox(width: Tok.s4),
          Flexible(child: Text(t('city.flagNote'), style: Tok.sub.copyWith(color: Tok.text3), overflow: TextOverflow.ellipsis)),
          const Spacer(),
          if (found.length > _rows)
            AppButton.quiet(_all ? t('city.showFewer') : t('city.showAll'), onPressed: () => setState(() => _all = !_all)),
        ]),
      ]),
    );
  }

  List<Widget> _row(Strings t, Map<String, dynamic> w, bool selected) {
    final share = w['spend_share'] as num, over = share > 1;
    return [
      Row(children: [
        Container(
          width: 42,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Tok.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? Tok.teal : Tok.line, width: selected ? 1.5 : 1),
          ),
          child: Text('${w['ward_code']}', style: Tok.body.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('${w['ward_name']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
      Text(fmt.money(w['budget']), style: const TextStyle(fontWeight: FontWeight.w400, color: Tok.text2)),
      Text(fmt.money(w['spend'])),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          SizedBox(width: 86, child: BudgetBar(budget: w['budget'] as num, spent: w['spend'] as num, showLabels: false)),
          const SizedBox(width: 10),
          Text(fmt.pct(share), style: TextStyle(fontWeight: FontWeight.w600, color: over ? Tok.red : Tok.ink)),
        ]),
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Ico.alert, size: 13, color: Tok.red),
              const SizedBox(width: 4),
              Text(t('city.overBy', {'amount': fmt.money((w['spend'] as num) - (w['budget'] as num))}),
                  style: Tok.sub.copyWith(color: Tok.red)),
            ]),
          ),
      ]),
      (w['open_flags'] as num) > 0 ? FlagPill('${w['open_flags']}') : Text('0', style: Tok.body.copyWith(color: Tok.text3)),
    ];
  }
}

class _MapPanel extends ConsumerWidget {
  const _MapPanel({required this.wards, required this.selected, required this.onSelect});
  final List<Map<String, dynamic>> wards;
  final String selected;
  final void Function(String code) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final w = wards.firstWhere((x) => x['ward_code'] == selected, orElse: () => wards.first);
    final share = w['spend_share'] as num, over = share > 1;
    final counts = List.filled(5, 0);
    for (final x in wards) {
      counts[shareStep(x['spend_share'] as num)]++;
    }
    return Panel(
      title: t('city.mapTitle'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(border: Border.all(color: Tok.tealDark, width: 2), borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(t('city.selected'), style: Tok.sub),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 580,
          child: Container(
            foregroundDecoration: BoxDecoration(border: Border.all(color: Tok.lineInset), borderRadius: BorderRadius.circular(Tok.rCard)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tok.rCard),
              child: Stack(children: [
                Positioned.fill(
                  child: AsyncView(
                    value: ref.watch(wardShapesProvider),
                    builder: (shapes) => WardMap(shapes: shapes, wards: wards, selected: selected, onTap: onSelect, onOpen: context.goWard),
                  ),
                ),
                // Selected ward card, like the mockup's tooltip; tapping it opens the ward.
                Positioned(
                  left: 12,
                  bottom: 34,
                  child: Pressable(
                    onTap: () => context.goWard(selected),
                    radius: 10,
                    semanticLabel: t('city.openWard', {'code': selected}),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: Tok.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Tok.line),
                        boxShadow: Tok.shadowControl,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('$selected · ${w['ward_name']}', style: Tok.body.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${t('city.ofBudget', {'spent': fmt.money(w['spend']), 'budget': fmt.money(w['budget'])})} · ', style: Tok.sub),
                          if (over) ...[const Icon(Ico.alert, size: 13, color: Tok.red), const SizedBox(width: 3)],
                          Text(fmt.pct(share), style: Tok.sub.copyWith(color: over ? Tok.red : Tok.ink, fontWeight: FontWeight.w600)),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: Tok.s3),
        Row(children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 10, child: _swatch(i))),
                const SizedBox(height: 6),
                Text(t('city.step$i'), style: Tok.sub.copyWith(color: i > 2 ? Tok.red : Tok.ink, fontWeight: i > 2 ? FontWeight.w500 : null)),
                Text(i > 2 ? t('city.stepOver', {'n': counts[i]}) : t('city.wardsN', {'n': counts[i]}), style: Tok.sub.copyWith(fontSize: 11.5)),
              ]),
            ),
          ],
        ]),
      ]),
    );
  }

  /// Legend swatch: plain teal steps, diagonal hatch for 100–110%, cross hatch over 110%.
  static Widget _swatch(int i) => Container(
        foregroundDecoration: BoxDecoration(border: Border.all(color: i > 2 ? Tok.red.withValues(alpha: 0.5) : Tok.line), borderRadius: BorderRadius.circular(3)),
        child: i < 3
            ? ColoredBox(color: mapScale[i])
            : Stack(fit: StackFit.expand, children: [
                Hatch(stripe: Tok.red.withValues(alpha: 0.7), background: mapScale[i], width: 1, gap: 3.5),
                if (i == 4) Transform.flip(flipX: true, child: Hatch(stripe: Tok.red.withValues(alpha: 0.7), background: Colors.transparent, width: 1, gap: 3.5)),
              ]),
      );
}

/// Real ward outlines shaded by spend against budget, over OpenStreetMap tiles (needs a network for the tiles).
class WardMap extends StatelessWidget {
  const WardMap({super.key, required this.shapes, required this.wards, required this.selected, required this.onTap, required this.onOpen});
  final Map<String, List<List<LatLng>>> shapes;
  final List<Map<String, dynamic>> wards;
  final String? selected;
  final void Function(String code) onTap, onOpen;

  @override
  Widget build(BuildContext context) {
    final share = {for (final w in wards) w['ward_code'] as String: w['spend_share'] as num};
    int step(String code) => shareStep(share[code] ?? 0);
    String? hit(LatLng p) => shapes.entries.where((e) => e.value.any((ring) => insideRing(p, ring))).map((e) => e.key).firstOrNull;
    final bounds = LatLngBounds.fromPoints([for (final rings in shapes.values) ...rings.first]);
    final stripe = Tok.red.withValues(alpha: 0.75);
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          // Extra room at the bottom for the attribution line.
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 36),
        ),
        // No wheel zoom, so scrolling the page over the map scrolls the page. No double-tap zoom, so taps act at once.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag | InteractiveFlag.flingAnimation | InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
        ),
        minZoom: 9,
        cameraConstraint: CameraConstraint.containCenter(bounds: bounds),
        // First tap selects a ward, a second tap on it opens it.
        onTap: (_, p) {
          final code = hit(p);
          if (code != null) code == selected ? onOpen(code) : onTap(code);
        },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'bmc_sathi'),
        PolygonLayer(polygons: [
          for (final e in shapes.entries)
            for (final ring in e.value)
              Polygon(points: ring, color: mapScale[step(e.key)].withValues(alpha: 0.85), borderColor: Tok.panel, borderStrokeWidth: 1),
        ]),
        // Over-budget wards also carry a hatch (diagonal 100–110%, cross over 110%), so colour is never alone.
        PolylineLayer(polylines: [
          for (final e in shapes.entries)
            if (step(e.key) > 2)
              for (final ring in e.value)
                for (final slope in step(e.key) == 4 ? const [1.0, -1.0] : const [1.0])
                  for (final seg in _hatch(e.key, ring, slope)) Polyline(points: seg, color: stripe, strokeWidth: 1),
        ]),
        // Selected outline on top of the hatch.
        PolygonLayer(polygons: [
          for (final ring in shapes[selected] ?? const <List<LatLng>>[])
            Polygon(points: ring, color: Colors.transparent, borderColor: Tok.tealDark, borderStrokeWidth: 3),
        ]),
        // Labels as markers: the polygon layer hides a label that does not fit its outline, which drops narrow wards.
        MarkerLayer(markers: [
          for (final e in shapes.entries)
            Marker(
              point: _centre(e.value.first),
              width: 40,
              height: 18,
              child: IgnorePointer(
                child: Center(
                  child: Text(e.key, style: Tok.sub.copyWith(color: step(e.key) == 2 ? Colors.white : Tok.ink, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap · OpenCity')),
      ],
    );
  }

  /// Hatch segments are fixed for the bundled outlines, so work them out once per ring and direction.
  static final _hatchCache = <String, List<List<LatLng>>>{};

  /// Stripes lat = slope·lng + c clipped to the ring: cross each line with every edge, pair up the crossings.
  static List<List<LatLng>> _hatch(String code, List<LatLng> ring, double slope, {double gap = 0.0045}) =>
      _hatchCache.putIfAbsent('$code/${ring.length}/${ring.first}/$slope', () {
        double cOf(LatLng p) => p.latitude - slope * p.longitude;
        final cs = ring.map(cOf);
        final lo = cs.reduce((a, b) => a < b ? a : b), hi = cs.reduce((a, b) => a > b ? a : b);
        final out = <List<LatLng>>[];
        for (var c = (lo / gap).ceil() * gap; c < hi; c += gap) {
          final xs = <double>[];
          for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
            final da = cOf(ring[i]) - c, db = cOf(ring[j]) - c;
            if ((da > 0) != (db > 0)) xs.add(ring[i].longitude + da / (da - db) * (ring[j].longitude - ring[i].longitude));
          }
          xs.sort();
          for (var k = 0; k + 1 < xs.length; k += 2) {
            out.add([LatLng(c + slope * xs[k], xs[k]), LatLng(c + slope * xs[k + 1], xs[k + 1])]);
          }
        }
        return out;
      });

  /// Middle of a ring's bounding box: close enough to place a label.
  static LatLng _centre(List<LatLng> ring) => LatLngBounds.fromPoints(ring).center;

  /// Ray casting: is the point inside the ring?
  static bool insideRing(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}
