import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
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

/// Real ward outlines shaded by spend against budget, over OpenStreetMap tiles (needs a network for the tiles).
class WardMap extends StatelessWidget {
  const WardMap({super.key, required this.shapes, required this.wards, required this.selected, required this.onTap, required this.onOpen});
  final Map<String, List<List<LatLng>>> shapes;
  final List<Map<String, dynamic>> wards;
  final String? selected;
  final void Function(String code) onTap, onOpen;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    final label = Theme.of(context).textTheme.labelMedium!;
    final share = {for (final w in wards) w['ward_code'] as String: w['spend_share'] as num};
    String? hit(LatLng p) => shapes.entries.where((e) => e.value.any((ring) => insideRing(p, ring))).map((e) => e.key).firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([for (final rings in shapes.values) ...rings.first]),
            // Extra room at the bottom for the attribution line.
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 36),
          ),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
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
                Polygon(
                  points: ring,
                  color: c.mapScale[shareStep(share[e.key] ?? 0)].withValues(alpha: 0.78),
                  borderColor: e.key == selected ? c.textPrimary : c.surface,
                  borderStrokeWidth: e.key == selected ? 3 : 1,
                ),
          ]),
          // Labels as markers: the polygon layer hides a label that does not fit its outline, which drops narrow wards.
          MarkerLayer(markers: [
            for (final e in shapes.entries)
              Marker(
                point: _centre(e.value.first),
                width: 40,
                height: 18,
                child: IgnorePointer(
                  child: Center(child: Text(e.key, style: label.copyWith(color: c.onMapScale[shareStep(share[e.key] ?? 0)], fontWeight: FontWeight.w600))),
                ),
              ),
          ]),
          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors · wards: OpenCity')),
        ],
      ),
    );
  }

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
