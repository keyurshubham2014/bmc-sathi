import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';

final searchProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, q) => apiGet(ref, '/trail/search', {'q': q}));

/// Keyed by the API path, e.g. `/trail/issue/12` or `/trail/work-order/WO25-00004`.
final trailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, path) => apiGet(ref, path));

class TrailSearchScreen extends ConsumerStatefulWidget {
  const TrailSearchScreen({super.key});
  @override
  ConsumerState<TrailSearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<TrailSearchScreen> {
  final _box = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _box.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return PageBody(children: [
      Text(t('trail.title'), style: tt.titleLarge),
      TextField(
        controller: _box,
        autofocus: true,
        decoration: InputDecoration(labelText: t('trail.search'), prefixIcon: const Icon(Icons.search)),
        onSubmitted: (v) => setState(() => _q = v.trim()),
        textInputAction: TextInputAction.search,
      ),
      if (_q.length < 3)
        SectionCard(child: EmptyState(t('trail.hint'), icon: Icons.timeline_outlined))
      else
        AsyncView(
          value: ref.watch(searchProvider(_q)),
          onRetry: () => ref.invalidate(searchProvider(_q)),
          builder: (data) {
            final complaints = List<Map<String, dynamic>>.from(data['complaints']);
            final jobs = List<Map<String, dynamic>>.from(data['work_orders']);
            final issues = List<Map<String, dynamic>>.from(data['issues']);
            if (complaints.isEmpty && jobs.isEmpty && issues.isEmpty) return SectionCard(child: EmptyState(t('trail.none', {'q': _q}), icon: Icons.search_off));
            Widget group(String title, List<Widget> rows) => SectionCard(title: title, padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm), child: Column(children: rows));
            Widget row(String title, String sub, String to, {Widget? trailing}) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(title, style: tt.labelLarge),
                  subtitle: Text(sub, style: tt.bodySmall),
                  trailing: trailing ?? const Icon(Icons.chevron_right),
                  onTap: () => context.go(to),
                );
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (issues.isNotEmpty)
                group(t('trail.group.issues'), [
                  for (final i in issues)
                    row('${i['category']} · ${i['road_name'] ?? '–'}', '${t('ward.label', {'code': i['ward_code']})} · ${t('plan.complaints', {'n': i['complaint_count']})} · ${fmt.date(i['last_reported_at'])}', '/trail/issue/${i['id']}', trailing: _StateChip('${i['state']}')),
                ]),
              if (complaints.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                group(t('trail.group.complaints'), [for (final c in complaints) row('${c['id']}', '${c['locality_text'] ?? '–'} · ${c['status']} · ${fmt.date(c['received_at'])}', '/trail/complaint/${c['id']}')]),
              ],
              if (jobs.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                group(t('trail.group.workOrders'), [for (final w in jobs) row('${w['id']}', '${w['road_name']} · ${w['work_type']} · ${w['contractor_name']}', '/trail/work-order/${w['id']}')]),
              ],
            ]);
          },
        ),
    ]);
  }
}

class _StateChip extends ConsumerWidget {
  const _StateChip(this.state);
  final String state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, icon) = switch (state) {
      'fixed' => (Tone.success, Icons.check_circle_outline),
      'fixed_reopened' => (Tone.flag, Icons.replay),
      'open' => (Tone.flag, Icons.pending_outlined),
      _ => (Tone.neutral, Icons.block),
    };
    return Pill(ref.watch(stringsProvider)('trail.state.$state'), tone: tone, icon: icon);
  }
}

/// One item end to end: complaints, issue, work order, road, outcome.
class TrailScreen extends ConsumerWidget {
  const TrailScreen(this.apiPath, {super.key});
  final String apiPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final canSeeFlags = ref.watch(sessionProvider)!.canSeeFlags;
    return AsyncView(
      value: ref.watch(trailProvider(apiPath)),
      onRetry: () => ref.invalidate(trailProvider(apiPath)),
      lines: 10,
      builder: (d) {
        final issue = d['issue'] == null ? null : Map<String, dynamic>.from(d['issue']);
        final w = d['work_order'] == null ? null : Map<String, dynamic>.from(d['work_order']);
        final road = d['road'] == null ? null : Map<String, dynamic>.from(d['road']);
        final plan = d['plan'] == null ? null : Map<String, dynamic>.from(d['plan']);
        final complaints = List<Map<String, dynamic>>.from(d['complaints']);
        final flags = List<Map<String, dynamic>>.from(d['flags']);
        final posts = List<Map<String, dynamic>>.from(d['social_posts']);
        Widget line(String s, {TextStyle? style}) => Padding(padding: const EdgeInsets.only(bottom: Gap.xs), child: Text(s, style: style ?? tt.bodyMedium));

        return PageBody(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: () => context.go('/trail'), icon: const Icon(Icons.arrow_back, size: 18), label: Text(t('trail.title'))),
          ),
          _Stage(1, t('trail.stage.complaints'), Icons.campaign_outlined, [
            if (complaints.isEmpty) Pill(t('trail.noComplaint'), tone: Tone.flag, icon: Icons.link_off),
            for (final (n, k) in complaints.indexed) ...[
              if (n > 0) const Divider(height: Gap.xl),
              Container(
                // The complaint the user searched for is marked with a rule, not colour alone.
                padding: k['complaint_id'] == d['highlight'] ? const EdgeInsets.only(left: Gap.md) : EdgeInsets.zero,
                decoration: k['complaint_id'] == d['highlight'] ? BoxDecoration(border: Border(left: BorderSide(color: c.primary, width: 3))) : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('${k['complaint_id']}', style: tt.labelLarge),
                    Text('${k['channel']} · ${fmt.dateTime(k['received_at'])} · ${k['status']}', style: tt.bodySmall),
                  ]),
                  const SizedBox(height: Gap.xs),
                  line('${k['description']}'),
                  if (k['text_en'] != null && k['text_en'] != k['description'])
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Pill(t('trail.translated'), tone: Tone.info, icon: Icons.translate),
                      const SizedBox(width: Gap.sm),
                      Expanded(child: Text('${k['text_en']}', style: tt.bodyMedium!.copyWith(color: c.textSecondary))),
                    ]),
                  if (k['category_clean'] != k['category_reported'])
                    Text(t('trail.original', {'category': k['category_reported']}), style: tt.bodySmall!.copyWith(decoration: TextDecoration.lineThrough)),
                  Text(t('trail.located', {'source': t('trail.source.${k['location_source']}')}), style: tt.bodySmall),
                ]),
              ),
            ],
          ]),
          if (issue != null)
            _Stage(2, t('trail.stage.issue'), Icons.merge_type, [
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${issue['category']}', style: tt.titleMedium),
                _StateChip('${issue['state']}'),
              ]),
              const SizedBox(height: Gap.xs),
              line('${t('ward.label', {'code': issue['ward_code']})} · ${t('trail.count', {'n': issue['complaint_count'], 'up': issue['upvotes_total']})}'),
              line(t('trail.severity', {'n': issue['severity']}), style: tt.bodySmall),
              if (posts.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                Text('${t('trail.social')} · ${t('trail.socialCount', {'n': posts.length})}', style: tt.labelLarge),
                const SizedBox(height: Gap.xs),
                for (final p in posts.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p['source']} · ${fmt.dateTime(p['posted_at'])}', style: tt.bodySmall),
                      Text('${p['text']}', style: tt.bodyMedium),
                      if (p['text_en'] != null) Text('${p['text_en']}', style: tt.bodyMedium!.copyWith(color: c.textSecondary)),
                    ]),
                  ),
              ],
              if (plan != null) ...[
                line(t('trail.planRank', {'rank': plan['rank'], 'score': (plan['risk_score'] as num).round()})),
                TextButton.icon(
                  onPressed: () => context.go('/ward/${wardSlug('${issue['ward_code']}')}?tab=plan'),
                  icon: const Icon(Icons.route_outlined, size: 18),
                  label: Text(t('plan.title')),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ]),
          _Stage(3, t('trail.stage.workOrder'), Icons.construction_outlined, [
            if (w == null)
              Pill(t('trail.neverFixed'), tone: Tone.flag, icon: Icons.report_gmailerrorred_outlined)
            else ...[
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${w['work_order_id']}', style: tt.titleMedium),
                Text('${w['contractor_name']}', style: tt.bodyMedium),
              ]),
              const SizedBox(height: Gap.xs),
              line('${w['repair_method']} · ${t('wo.area', {'area': w['area_sqm']})} · ${fmt.date(w['assigned_at'])} → ${fmt.date(w['completed_at'])}'),
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(fmt.money(w['cost_inr']), style: tt.titleMedium),
                Text(t('wo.expected', {'amount': fmt.money(w['expected_cost'])}), style: tt.bodySmall),
                Pill(t('wo.timesRate', {'ratio': fmt.ratio(w['cost_ratio'])}), tone: (w['cost_ratio'] as num) > 1.5 ? Tone.flag : Tone.neutral),
              ]),
              if ('${w['engineer_remark'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Gap.sm), child: Text('${t('trail.remark')}: ${w['engineer_remark']}', style: tt.bodySmall)),
              if (flags.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Text(t('trail.flags'), style: tt.labelLarge),
                const SizedBox(height: Gap.xs),
                Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [
                  for (final f in flags)
                    InkWell(
                      onTap: canSeeFlags && f['tier'] == 'flag' ? () => context.go('/flags/${f['flag_type']}/${w['work_order_id']}') : null,
                      child: Pill('${t('flags.tab.${f['tier'] == 'watch' ? 'watch' : f['flag_type']}')} · ${fmt.money(f['amount_at_stake'])}', tone: Tone.flag, icon: Icons.flag_outlined),
                    ),
                ]),
              ],
            ],
          ]),
          if (road != null)
            _Stage(4, t('trail.stage.road'), Icons.add_road, [
              Text('${road['road_name']} · ${road['segment_no']} (${road['road_id']})', style: tt.titleMedium),
              const SizedBox(height: Gap.xs),
              line(t('trail.surface', {'type': road['road_type'], 'surface': road['surface'], 'lanes': road['lanes']})),
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(t('trail.resurfaced', {'date': fmt.date(road['last_resurfaced'])}), style: tt.bodySmall),
                road['under_dlp'] == true ? Pill(t('wo.dlp'), tone: Tone.flag, icon: Icons.gavel_outlined) : Pill(t('trail.notDlp')),
                if (road['bus_route'] == true) Pill(t('plan.reason.bus'), icon: Icons.directions_bus_outlined),
              ]),
            ]),
          _Stage(5, t('trail.stage.outcome'), Icons.flag_circle_outlined, [
            if (w == null)
              line(plan == null ? t('trail.outcome.pending') : t('trail.daysOpen', {'n': (plan['days_open'] as num).round()}))
            else ...[
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [
                if (w['sla_met'] != null) Pill('${t(w['sla_met'] ? 'wo.slaMet' : 'wo.slaMissed')} · ${t('trail.sla', {'h': w['sla_hours']})}', tone: w['sla_met'] ? Tone.success : Tone.flag, icon: w['sla_met'] ? Icons.check : Icons.schedule),
                if (w['reopened_within_30d'] != null) Pill(t(w['reopened_within_30d'] ? 'wo.reopened' : 'wo.held'), tone: w['reopened_within_30d'] ? Tone.flag : Tone.success, icon: w['reopened_within_30d'] ? Icons.replay : Icons.check),
              ]),
              const SizedBox(height: Gap.sm),
              line(w['reopened_within_30d'] == null ? t('trail.outcome.pending') : t(w['reopened_within_30d'] ? 'trail.outcome.reopened' : 'trail.outcome.held')),
            ],
          ]),
        ]);
      },
    );
  }
}

/// A numbered stage of the trail.
class _Stage extends StatelessWidget {
  const _Stage(this.n, this.title, this.icon, this.children);
  final int n;
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Text('$n', style: tt.labelLarge!.copyWith(color: c.onPrimary)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, size: 18, color: c.textSecondary), const SizedBox(width: Gap.xs), Text(title, style: tt.labelLarge!.copyWith(color: c.textSecondary))]),
              const SizedBox(height: Gap.sm),
              ...children,
            ]),
          ),
        ]),
      ),
    );
  }
}
